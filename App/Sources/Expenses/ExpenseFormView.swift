import SwiftUI
import SwiftData
import BifazModels
import BifazDesign
import BifazReading

/// Quick add, edit, and confirmation of a read receipt, presented as a sheet.
///
/// The fast path is amount → category → Save: the amount field is focused on
/// open, the space comes from the current filter, the merchant can prefill
/// space and category from what Bifaz learned last time. For a captured
/// receipt the form is prefilled with what was read and shows, per field,
/// how sure the reader is; nothing is saved until the user confirms.
struct ExpenseFormView: View {
    private let expense: Expense?
    private let capture: CapturedReceipt?
    private let onDeleted: () -> Void
    /// VAT read from the receipt, restored when the user switches to Pro.
    private let readVATRate: VATRate?
    private let readVATOverride: Decimal?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.receiptStore) private var receiptStore
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var draft: ExpenseDraft
    @State private var amountText: String
    @State private var merchantSuggestions: [String] = []
    @State private var isConfirmingDelete = false
    @State private var saveError: Error?
    @State private var savedCount = 0
    /// Confidence of each read value; a field drops out once the user edits it.
    @State private var confidence: [ReadField: ReadingConfidence] = [:]
    @FocusState private var focus: Field?

    private enum Field { case amount, merchant, note }
    private enum ReadField { case amount, merchant, date, vat }

    init(editing expense: Expense? = nil, defaultSpace: Space = .personal, onDeleted: @escaping () -> Void = {}) {
        self.expense = expense
        self.capture = nil
        self.onDeleted = onDeleted
        self.readVATRate = nil
        self.readVATOverride = nil
        let draft = expense.map(ExpenseDraft.init(expense:)) ?? ExpenseDraft(space: defaultSpace)
        _draft = State(initialValue: draft)
        _amountText = State(initialValue: draft.amount.map { $0.formatted(Self.amountInputStyle) } ?? "")
    }

    /// Confirmation of a captured receipt, prefilled with what was read.
    init(capture: CapturedReceipt, defaultSpace: Space) {
        let fields = capture.reading.fields
        self.expense = nil
        self.capture = capture
        self.onDeleted = {}
        self.readVATRate = fields.vatRate.flatMap { VATRate(fraction: $0.value) }
        // Several rates: keep the printed total VAT instead of a single-rate computation.
        self.readVATOverride = fields.vatLines.count > 1 ? fields.vatAmount?.value : nil
        var draft = ExpenseDraft(
            amount: fields.total?.value,
            merchant: fields.merchant?.value ?? "",
            date: fields.date?.value ?? .now,
            space: defaultSpace,
            vatRate: defaultSpace == .pro ? readVATRate : nil
        )
        draft.source = .scanner
        draft.vatAmountOverride = defaultSpace == .pro ? readVATOverride : nil
        _draft = State(initialValue: draft)
        _amountText = State(initialValue: draft.amount.map { $0.formatted(Self.amountInputStyle) } ?? "")
        var confidence: [ReadField: ReadingConfidence] = [:]
        confidence[.amount] = fields.total?.confidence
        confidence[.merchant] = fields.merchant?.confidence
        confidence[.date] = fields.date?.confidence
        confidence[.vat] = fields.vatRate?.confidence ?? fields.vatAmount?.confidence
        _confidence = State(initialValue: confidence)
    }

    private static let amountInputStyle = Decimal.FormatStyle.number.precision(.fractionLength(2)).grouping(.never)

    private var isEditing: Bool { expense != nil }
    private var isConfirmingCapture: Bool { capture != nil }
    private var spaceCategories: [ExpenseCategory] { categories.filter { $0.space == draft.space } }
    private var showsVAT: Bool { isVATRegistered && draft.space == .pro }
    private var amountIsInvalid: Bool { !amountText.isEmpty && MoneyParser.parse(amountText) == nil }

    /// "€" as the current locale writes it.
    private static let currencySymbol: String = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.currencySymbol
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let capture { ReadReceiptHeader(capture: capture) }
                    amountSection
                    field("form.space") { spacePicker }
                    field("form.category") { categoryPicker }
                    field("form.merchant", read: .merchant) { merchantField }
                    field("form.date", read: .date) {
                        DatePicker(selection: $draft.date, displayedComponents: .date) {
                            Text("form.date")
                        }
                        .labelsHidden()
                        .tint(.bifazInk)
                    }
                    if showsVAT {
                        field("form.vat", read: .vat) { vatPicker }
                    }
                    field("form.note", divider: false) {
                        TextField("form.note.placeholder", text: $draft.note, axis: .vertical)
                            .font(.bifazBody)
                            .lineLimit(1...4)
                            .focused($focus, equals: .note)
                    }
                    if isEditing {
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label {
                                Text("form.delete")
                            } icon: {
                                BifazIconView(.trash, size: 18)
                            }
                        }
                        .buttonStyle(.bifazSecondary)
                        .foregroundStyle(.bifazError)
                        .accessibilityIdentifier("ui.formDelete")
                        .padding(.top, BifazSpacing.xxl)
                    }
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.bottom, BifazSpacing.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.bifazPaper)
            .navigationTitle(isEditing ? "form.title.edit" : isConfirmingCapture ? "form.title.confirm" : "form.title.new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onChange(of: amountText) { _, text in
                let amount = MoneyParser.parse(text)
                if amount != draft.amount { confidence[.amount] = nil }
                draft.amount = amount
            }
            .onChange(of: draft.merchant) { old, _ in if !old.isEmpty { confidence[.merchant] = nil } }
            .onChange(of: draft.date) { confidence[.date] = nil }
            .onChange(of: draft.space) { _, space in spaceChanged(to: space) }
            .onAppear {
                if isConfirmingCapture {
                    if !draft.merchant.isEmpty { applyMemory(for: draft.merchant) }
                    spaceChanged(to: draft.space)
                } else if !isEditing {
                    spaceChanged(to: draft.space)
                    focus = .amount
                }
            }
            .confirmationDialog("form.delete.title", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("form.delete", role: .destructive, action: delete)
                    .accessibilityIdentifier("ui.formDeleteConfirm")
            } message: {
                DeleteExpenseMessage(merchant: expense?.merchant ?? "")
            }
            .alert("form.error.title", isPresented: .constant(saveError != nil)) {
                Button("form.error.ok") { saveError = nil }
            } message: {
                Text("form.error.message")
            }
            .sensoryFeedback(.success, trigger: savedCount)
        }
    }

    // MARK: Sections

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            HStack(spacing: BifazSpacing.xs) {
                Text("form.amount")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
                if let level = confidence[.amount] { ConfidenceTag(confidence: level) }
            }
            HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
                TextField(text: $amountText, prompt: Text(verbatim: Decimal(0).formatted(Self.amountInputStyle))) {
                    Text("form.amount")
                }
                .font(.bifazAmountHero)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("ui.formAmount")
                .focused($focus, equals: .amount)
                .foregroundStyle(.bifazInk)
                Text(verbatim: Self.currencySymbol)
                    .font(.bifazAmountHero)
                    .foregroundStyle(.bifazInkSecondary)
                    .accessibilityHidden(true)
            }
            if amountIsInvalid {
                Text("form.amount.invalid")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazError)
            }
        }
        .padding(.top, BifazSpacing.l)
        .padding(.bottom, BifazSpacing.l)
    }

    private var spacePicker: some View {
        HStack(spacing: BifazSpacing.xs) {
            ForEach(Space.allCases) { space in
                FilterChip(space.title, icon: space.icon, symbolTint: space.color, isSelected: draft.space == space) {
                    draft.space = space
                }
            }
        }
    }

    private var categoryPicker: some View {
        FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
            ForEach(spaceCategories) { category in
                let isSelected = draft.category?.id == category.id
                Button {
                    draft.category = isSelected ? nil : category
                } label: {
                    CategoryChip(category.displayName, icon: category.icon, tint: draft.space.color, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: draft.category?.id)
    }

    private var merchantField: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("form.merchant.placeholder", text: $draft.merchant)
                .accessibilityIdentifier("ui.formMerchant")
                .font(.bifazBody)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .merchant)
                .onChange(of: draft.merchant) { _, text in
                    merchantSuggestions = MerchantMemory.merchants(matching: text, in: context)
                        .filter { $0 != text }
                }
                .onSubmit { applyMemory(for: draft.merchant) }
            if focus == .merchant {
                ForEach(merchantSuggestions, id: \.self) { name in
                    Button {
                        draft.merchant = name
                        applyMemory(for: name)
                        focus = nil
                    } label: {
                        Text(verbatim: name)
                            .font(.bifazBody)
                            .foregroundStyle(.bifazInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, BifazSpacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var vatPicker: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
                ForEach(VATRate.allCases) { rate in
                    FilterChip(LocalizedStringResource(stringLiteral: rate.percentText), isSelected: draft.vatRate == rate) {
                        draft.vatRate = draft.vatRate == rate ? nil : rate
                        draft.vatAmountOverride = nil
                        confidence[.vat] = nil
                    }
                }
            }
            if let vat = draft.vatAmount {
                Text(draft.vatAmountOverride != nil
                     ? "form.vat.multiple \(vat.formatted(.currency(code: "EUR")))"
                     : "form.vat.included \(vat.formatted(.currency(code: "EUR")))")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                BifazIconView(.close, size: 18)
            }
            .accessibilityLabel(Text("form.cancel"))
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("form.save", action: save)
                .accessibilityIdentifier("ui.formSave")
                .disabled(!draft.isValid)
                .fontWeight(.semibold)
        }
    }

    private func field(
        _ label: LocalizedStringResource,
        read: ReadField? = nil,
        divider: Bool = true,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            HairlineDivider()
            HStack(spacing: BifazSpacing.xs) {
                Text(label)
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
                    .accessibilityAddTraits(.isHeader)
                if let read, let level = confidence[read] { ConfidenceTag(confidence: level) }
            }
            content()
        }
        .padding(.bottom, BifazSpacing.l)
    }

    // MARK: Actions

    /// Keeps the category and VAT consistent with the chosen space.
    private func spaceChanged(to space: Space) {
        if let category = draft.category, category.space != space { draft.category = nil }
        if space == .pro, isVATRegistered {
            if draft.vatRate == nil, draft.vatAmountOverride == nil {
                if isConfirmingCapture {
                    // What the receipt says, never a guess.
                    draft.vatRate = readVATRate
                    draft.vatAmountOverride = readVATOverride
                } else if !isEditing || expense?.space != .pro {
                    draft.vatRate = .standard
                }
            }
        } else {
            draft.vatRate = nil
            draft.vatAmountOverride = nil
        }
    }

    /// Prefills space and category from what Bifaz learned about this merchant.
    private func applyMemory(for merchant: String) {
        guard let rule = MerchantMemory.suggestion(for: merchant, in: context) else { return }
        draft.space = rule.space
        if let category = rule.category { draft.category = category }
    }

    private func save() {
        var storedFiles: StoredReceiptFiles?
        do {
            if let expense {
                try ExpenseService.update(expense, with: draft, in: context)
            } else if let capture {
                if let receiptStore {
                    storedFiles = try StoredReceiptFiles.store(
                        fileData: capture.fileData,
                        fileExtension: capture.fileExtension,
                        typeIdentifier: capture.typeIdentifier,
                        thumbnailData: capture.thumbnailData,
                        recognizedText: capture.reading.recognizedText,
                        in: receiptStore
                    )
                }
                try ExpenseService.create(from: draft, receipt: storedFiles, in: context)
            } else {
                try ExpenseService.create(from: draft, in: context)
            }
            savedCount += 1
            dismiss()
        } catch {
            if let storedFiles, let receiptStore {
                receiptStore.remove(storedFiles.fileName)
                receiptStore.remove(storedFiles.thumbnailFileName)
            }
            Log.app.error("Saving expense failed: \(String(describing: type(of: error)), privacy: .public)")
            saveError = error
        }
    }

    private func delete() {
        guard let expense else { return }
        do {
            try ExpenseService.delete(expense, in: context, store: receiptStore)
            dismiss()
            onDeleted()
        } catch {
            Log.app.error("Deleting expense failed: \(String(describing: error), privacy: .public)")
            saveError = error
        }
    }
}

/// The captured receipt at the top of the confirmation form: thumbnail and how it was read.
private struct ReadReceiptHeader: View {
    let capture: CapturedReceipt

    var body: some View {
        HStack(spacing: BifazSpacing.m) {
            ReceiptThumbnail(
                image: capture.thumbnailData.flatMap(UIImage.init(data:)).map(Image.init(uiImage:)),
                state: .attached,
                side: 56
            )
            VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
                Text(capture.reading.fields.isEmpty ? "form.read.nothing" : "form.read.done")
                    .font(.bifazHeadline)
                    .foregroundStyle(.bifazInk)
                Text(capture.reading.method == .model ? "form.read.model" : "form.read.rules")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            }
        }
        .padding(.top, BifazSpacing.l)
        .accessibilityElement(children: .combine)
    }
}

/// A small coloured tag saying how sure the reader is about a field.
private struct ConfidenceTag: View {
    let confidence: ReadingConfidence

    var body: some View {
        HStack(spacing: BifazSpacing.xxs) {
            BifazIconView(icon, size: 12, relativeTo: .caption)
            Text(title)
        }
        .font(.bifazLabel)
        .foregroundStyle(color)
        .padding(.horizontal, BifazSpacing.xs)
        .padding(.vertical, 2)
        .background(tint, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var title: LocalizedStringResource {
        switch confidence {
        case .high: "form.read.high"
        case .medium: "form.read.medium"
        case .low: "form.read.low"
        }
    }

    private var icon: BifazIcon {
        switch confidence {
        case .high: .check
        case .medium: .info
        case .low: .warning
        }
    }

    private var color: Color {
        switch confidence {
        case .high: .bifazSuccess
        case .medium: .bifazWarning
        case .low: .bifazError
        }
    }

    private var tint: Color {
        switch confidence {
        case .high: .bifazSuccessTint
        case .medium: .bifazWarningTint
        case .low: .bifazErrorTint
        }
    }
}

#Preview("New · Light") {
    ExpenseFormView(defaultSpace: .pro)
        .modelContainer(PreviewContainer.sample)
}

#Preview("New · Dark") {
    ExpenseFormView(defaultSpace: .personal)
        .modelContainer(PreviewContainer.sample)
        .preferredColorScheme(.dark)
}

#Preview("New · Large text") {
    ExpenseFormView(defaultSpace: .pro)
        .modelContainer(PreviewContainer.sample)
        .dynamicTypeSize(.accessibility3)
}
