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
    /// VAT read from the receipt (one line per rate), restored when the user switches to Pro.
    private let readVAT: [VATPart]
    /// The rate read when the total was not: no lines can be built, the rate is still useful.
    private let readVATRate: VATRate?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.receiptStore) private var receiptStore
    @Environment(AppNavigation.self) private var navigation: AppNavigation?
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var draft: ExpenseDraft
    @State private var amountText: String
    @State private var secondVATText = ""
    @State private var rateLookup: ExchangeRateService.Lookup?
    @State private var isLookingUp = false
    /// VAT fields of a foreign-currency expense are hidden until the user adds them.
    @State private var showsForeignVAT = false
    @State private var tagsAreProposal = false
    @State private var merchantSuggestions: [String] = []
    @State private var isConfirmingDelete = false
    @State private var saveError: Error?
    @State private var savedCount = 0
    /// Confidence of each read value; a field drops out once the user edits it.
    @State private var confidence: [ReadField: ReadingConfidence] = [:]
    /// The category was proposed by Bifaz (merchant memory or receipt hints), not chosen.
    @State private var categoryIsProposal = false
    /// The draft as the form opened (after prefilling), to spot unsaved changes.
    @State private var baseline: ExpenseDraft?
    @State private var isConfirmingDiscard = false
    @FocusState private var focus: Field?

    private enum Field { case amount, merchant, note }
    private enum ReadField { case amount, merchant, date, vat }

    init(editing expense: Expense? = nil, defaultSpace: Space = .personal, onDeleted: @escaping () -> Void = {}) {
        self.expense = expense
        self.capture = nil
        self.onDeleted = onDeleted
        self.readVAT = []
        self.readVATRate = nil
        let draft = expense.map(ExpenseDraft.init(expense:)) ?? ExpenseDraft(space: defaultSpace)
        _draft = State(initialValue: draft)
        _amountText = State(initialValue: draft.amount.map { $0.formatted(Self.amountInputStyle) } ?? "")
        _secondVATText = State(initialValue: draft.secondVAT?.total.map { $0.formatted(Self.amountInputStyle) } ?? "")
    }

    /// Confirmation of a captured receipt, prefilled with what was read.
    init(capture: CapturedReceipt, defaultSpace: Space) {
        let fields = capture.reading.fields
        self.expense = nil
        self.capture = capture
        self.onDeleted = {}
        self.readVATRate = fields.vatRate.flatMap { VATRate(fraction: $0.value) }
        // One line per printed rate (see the rounding rule on `VATPart`).
        var printed = fields.vatLines.map { PrintedVATLine(rate: $0.rate, base: $0.base, vat: $0.vat) }
        if printed.isEmpty, let rate = fields.vatRate?.value { printed = [PrintedVATLine(rate: rate)] }
        self.readVAT = fields.total.map { VATBreakdown.lines(fromPrinted: printed, total: $0.value) } ?? []
        var draft = ExpenseDraft(
            amount: fields.total?.value,
            merchant: fields.merchant?.value ?? "",
            date: fields.date?.value ?? .now,
            space: defaultSpace
        )
        draft.source = .scanner
        draft.currencyCode = fields.currencyCode
        if defaultSpace == .pro, fields.currencyCode == "EUR" { Self.applyRead(readVAT, rate: readVATRate, to: &draft) }
        _draft = State(initialValue: draft)
        _amountText = State(initialValue: draft.amount.map { $0.formatted(Self.amountInputStyle) } ?? "")
        _secondVATText = State(initialValue: draft.secondVAT?.total.map { $0.formatted(Self.amountInputStyle) } ?? "")
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
    private var showsVAT: Bool {
        isVATRegistered && draft.space == .pro && (!draft.isForeignCurrency || showsForeignVAT)
    }
    private var amountIsInvalid: Bool { !amountText.isEmpty && MoneyParser.parse(amountText) == nil }
    private var hasChanges: Bool { baseline.map { $0 != draft } ?? false }
    /// A read receipt or unsaved changes would be lost: ask before closing.
    private var closingLosesWork: Bool { isConfirmingCapture || hasChanges }

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
                    field("form.category", proposed: categoryIsProposal && draft.category != nil) { categoryPicker }
                    if draft.space == .pro {
                        field("form.tags", proposed: tagsAreProposal && (draft.client != nil || draft.project != nil)) {
                            HStack(spacing: BifazSpacing.xs) {
                                TagPicker(kind: .client, selection: $draft.client)
                                TagPicker(kind: .project, selection: $draft.project)
                            }
                        }
                    }
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
                    } else if isVATRegistered, draft.space == .pro, draft.isForeignCurrency {
                        Button {
                            showsForeignVAT = true
                        } label: {
                            Label { Text("form.currency.addVAT") } icon: { BifazIconView(.plus, size: 16) }
                                .font(.bifazCaption)
                                .foregroundStyle(.bifazInk)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, BifazSpacing.l)
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
                if amount != draft.amount {
                    confidence[.amount] = nil
                    // Read lines belong to the read total; a new amount goes back to hand rates.
                    if draft.fixedVATLines != nil {
                        draft.clearFixedVAT()
                        confidence[.vat] = nil
                    }
                }
                draft.amount = amount
            }
            .onChange(of: secondVATText) { _, text in
                draft.secondVAT?.total = MoneyParser.parse(text)
            }
            .onChange(of: draft.merchant) { old, _ in if !old.isEmpty { confidence[.merchant] = nil } }
            .onChange(of: draft.date) {
                confidence[.date] = nil
                // An ECB rate belongs to a day: follow the expense's date (a typed rate stays).
                if draft.isForeignCurrency, draft.exchangeRate?.source != .manual { lookUpRate() }
            }
            .onChange(of: draft.currencyCode) { _, code in
                draft.amountInEUROverride = nil
                draft.exchangeRate = nil
                if code != "EUR", !showsForeignVAT {
                    draft.vatRate = nil
                    draft.fixedVATLines = nil
                    removeSecondVAT()
                }
                if code != "EUR" { lookUpRate() }
            }
            .onChange(of: draft.client) { tagsAreProposal = false }
            .onChange(of: draft.project) { tagsAreProposal = false }
            .onChange(of: draft.space) { _, space in
                spaceChanged(to: space)
                if isConfirmingCapture, draft.category == nil { proposeCategory() }
            }
            .onAppear {
                if draft.isForeignCurrency, draft.exchangeRate == nil { lookUpRate() }
                if isEditing, draft.isForeignCurrency, draft.vatRate != nil || draft.fixedVATLines != nil { showsForeignVAT = true }
                if isConfirmingCapture {
                    if !draft.merchant.isEmpty { applyMemory(for: draft.merchant) }
                    spaceChanged(to: draft.space)
                    proposeCategory()
                } else if !isEditing {
                    spaceChanged(to: draft.space)
                    focus = .amount
                }
                if baseline == nil { baseline = draft }
            }
            .interactiveDismissDisabled(closingLosesWork)
            .confirmationDialog(
                isConfirmingCapture ? "form.discard.receipt.title" : "form.discard.changes.title",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("form.discard.confirm", role: .destructive) { dismiss() }
                    .accessibilityIdentifier("ui.formDiscardConfirm")
                Button("form.discard.keep", role: .cancel) {}
            } message: {
                if isConfirmingCapture { Text("form.discard.receipt.message") }
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
                CurrencyMenu(currencyCode: $draft.currencyCode)
            }
            if amountIsInvalid {
                Text("form.amount.invalid")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazError)
            }
            if draft.isForeignCurrency {
                ConversionPanel(draft: $draft, lookup: rateLookup, isLookingUp: isLookingUp)
                    .padding(.top, BifazSpacing.xs)
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
                    categoryIsProposal = false
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
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            if let lines = draft.fixedVATLines {
                // Read from the receipt: shown as printed; picking a rate switches to hand rates.
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    VATLineRow(line: line)
                }
            }
            rateChips(selection: draft.fixedVATLines == nil ? draft.vatRate : nil) { rate in
                draft.clearFixedVAT()
                draft.vatRate = draft.vatRate == rate && draft.secondVAT == nil ? nil : rate
                if draft.vatRate == nil { removeSecondVAT() }
                confidence[.vat] = nil
            }
            if draft.fixedVATLines == nil, draft.vatRate != nil {
                if let second = draft.secondVAT {
                    secondVATEditor(second)
                } else {
                    Button {
                        draft.secondVAT = .init(rate: draft.vatRate == .standard ? .reduced : .standard)
                        confidence[.vat] = nil
                    } label: {
                        Label {
                            Text("form.vat.addRate")
                        } icon: {
                            BifazIconView(.plus, size: 16)
                        }
                        .font(.bifazCaption)
                        .foregroundStyle(.bifazInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ui.formVATAddRate")
                }
            }
            if let vat = draft.vatAmount {
                Text(draft.vatLines.count > 1
                     ? "form.vat.multiple \(vat.formatted(.currency(code: "EUR")))"
                     : "form.vat.included \(vat.formatted(.currency(code: "EUR")))")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            }
        }
    }

    private func rateChips(selection: VATRate?, action: @escaping (VATRate) -> Void) -> some View {
        FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
            ForEach(VATRate.allCases) { rate in
                FilterChip(LocalizedStringResource(stringLiteral: rate.percentText), isSelected: selection == rate) {
                    action(rate)
                }
            }
        }
    }

    /// The second rate and the part of the amount it covers; the main rate takes the rest.
    private func secondVATEditor(_ second: ExpenseDraft.SecondVAT) -> some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            HStack {
                Text("form.vat.secondRate")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
                Spacer()
                Button("form.vat.removeRate", action: removeSecondVAT)
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInk)
                    .buttonStyle(.plain)
            }
            rateChips(selection: second.rate) { rate in
                draft.secondVAT?.rate = rate
            }
            HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
                TextField(text: $secondVATText, prompt: Text(verbatim: Decimal(0).formatted(Self.amountInputStyle))) {
                    Text("form.vat.secondAmount")
                }
                .font(.bifazBody)
                .monospacedDigit()
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("ui.formVATSecondAmount")
                .fixedSize()
                Text(verbatim: Self.currencySymbol)
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInkSecondary)
                    .accessibilityHidden(true)
                Text("form.vat.secondAmount")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
                    .accessibilityHidden(true)
            }
            if draft.validate() == .secondVATPartInvalid, !secondVATText.isEmpty {
                Text("form.vat.secondAmount.invalid")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazError)
            }
        }
    }

    private func removeSecondVAT() {
        draft.secondVAT = nil
        secondVATText = ""
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if closingLosesWork { isConfirmingDiscard = true } else { dismiss() }
            } label: {
                BifazIconView(.close, size: 18)
            }
            .accessibilityLabel(Text("form.cancel"))
            .accessibilityIdentifier("ui.formClose")
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
        proposed: Bool = false,
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
                if proposed { ProposalTag() }
            }
            content()
        }
        .padding(.bottom, BifazSpacing.l)
    }

    // MARK: Actions

    /// Keeps the category and VAT consistent with the chosen space.
    private func spaceChanged(to space: Space) {
        if let category = draft.category, category.space != space { draft.category = nil }
        if space == .pro, isVATRegistered, !draft.isForeignCurrency || showsForeignVAT {
            if draft.vatRate == nil, draft.fixedVATLines == nil {
                if isConfirmingCapture {
                    // What the receipt says, never a guess.
                    Self.applyRead(readVAT, rate: readVATRate, to: &draft)
                    secondVATText = draft.secondVAT?.total.map { $0.formatted(Self.amountInputStyle) } ?? ""
                } else if !isEditing || expense?.space != .pro {
                    draft.vatRate = .standard
                }
            }
        } else {
            draft.vatRate = nil
            draft.fixedVATLines = nil
            removeSecondVAT()
        }
    }

    /// The VAT read from a receipt: its lines, or only its rate when the total was not read.
    private static func applyRead(_ lines: [VATPart], rate: VATRate?, to draft: inout ExpenseDraft) {
        if lines.isEmpty {
            draft.vatRate = rate
        } else {
            draft.setVAT(lines)
        }
    }

    /// Prefills space and category from what Bifaz learned about this merchant.
    private func applyMemory(for merchant: String) {
        guard let rule = MerchantMemory.suggestion(for: merchant, in: context) else { return }
        draft.space = rule.space
        if let category = rule.category {
            draft.category = category
            categoryIsProposal = isConfirmingCapture
        }
        // Pro: the client and project of last time, as a proposal.
        if rule.space == .pro, draft.client == nil, draft.project == nil, rule.client != nil || rule.project != nil {
            draft.client = rule.client.flatMap { $0.isArchived ? nil : $0 }
            draft.project = rule.project.flatMap { $0.isArchived ? nil : $0 }
            tagsAreProposal = true
        }
    }

    /// Asks the rate service for the expense's currency and day (download at most
    /// once a day, only when allowed); falls back to the stored table, or to typing.
    private func lookUpRate() {
        let code = draft.currencyCode
        let date = draft.date
        guard code != "EUR" else { return }
        isLookingUp = true
        Task {
            let lookup = await ExchangeRates.service.lookup(code, on: date, allowDownload: ExchangeRates.downloadsAllowed)
            guard draft.currencyCode == code else { return }
            rateLookup = lookup
            isLookingUp = false
            if draft.exchangeRate?.source != .manual { draft.exchangeRate = lookup.quote }
        }
    }

    /// For a read receipt, proposes a category when none is set: the merchant's
    /// last one, else a clear hint from the brand or the text, else nothing.
    private func proposeCategory() {
        guard let capture else { return }
        if draft.category == nil {
            draft.category = CategoryHint.proposal(
                merchant: draft.merchant,
                text: capture.reading.recognizedText,
                space: draft.space,
                in: context
            )
        }
        categoryIsProposal = draft.category != nil
    }

    private func save() {
        var storedFiles: StoredReceiptFiles?
        // The budget of the chosen category, before and after, for the in-app alert.
        let budgetBefore = draft.category.flatMap { try? BudgetService.status(of: $0, at: draft.date, in: context) }
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
            if let category = draft.category,
               let alert = BudgetService.alert(
                   before: budgetBefore,
                   after: try? BudgetService.status(of: category, at: draft.date, in: context)
               ) {
                navigation?.budgetAlert = alert
            }
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
/// A VAT line read from a receipt: rate, base and VAT.
private struct VATLineRow: View {
    let line: VATPart

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: line.rateText)
                .font(.bifazBody)
                .foregroundStyle(.bifazInk)
            Spacer(minLength: BifazSpacing.s)
            Text("form.vat.lineAmounts \(line.base.formatted(.currency(code: "EUR"))) \(line.vat.formatted(.currency(code: "EUR")))")
                .font(.bifazCaption)
                .monospacedDigit()
                .foregroundStyle(.bifazInkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

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

/// A neutral tag next to the category when Bifaz proposed it.
private struct ProposalTag: View {
    var body: some View {
        HStack(spacing: BifazSpacing.xxs) {
            BifazIconView(.info, size: 12, relativeTo: .caption)
            Text("form.category.proposed")
        }
        .font(.bifazLabel)
        .foregroundStyle(Color.bifazInkSecondary)
        .padding(.horizontal, BifazSpacing.xs)
        .padding(.vertical, 2)
        .overlay(Capsule().strokeBorder(Color.bifazHairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ui.categoryProposed")
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
