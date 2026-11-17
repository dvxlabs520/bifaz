import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Quick add and edit form, presented as a sheet.
///
/// The fast path is amount → category → Save: the amount field is focused on
/// open, the space comes from the current filter, the merchant can prefill
/// space and category from what Bifaz learned last time.
struct ExpenseFormView: View {
    private let expense: Expense?
    private let onDeleted: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var draft: ExpenseDraft
    @State private var amountText: String
    @State private var merchantSuggestions: [String] = []
    @State private var isConfirmingDelete = false
    @State private var saveError: Error?
    @State private var savedCount = 0
    @FocusState private var focus: Field?

    private enum Field { case amount, merchant, note }

    init(editing expense: Expense? = nil, defaultSpace: Space = .personal, onDeleted: @escaping () -> Void = {}) {
        self.expense = expense
        self.onDeleted = onDeleted
        let draft = expense.map(ExpenseDraft.init(expense:)) ?? ExpenseDraft(space: defaultSpace)
        _draft = State(initialValue: draft)
        _amountText = State(initialValue: draft.amount.map { $0.formatted(Self.amountInputStyle) } ?? "")
    }

    private static let amountInputStyle = Decimal.FormatStyle.number.precision(.fractionLength(2)).grouping(.never)

    private var isEditing: Bool { expense != nil }
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
                    amountSection
                    field("form.space") { spacePicker }
                    field("form.category") { categoryPicker }
                    field("form.merchant") { merchantField }
                    field("form.date") {
                        DatePicker(selection: $draft.date, displayedComponents: .date) {
                            Text("form.date")
                        }
                        .labelsHidden()
                        .tint(.bifazInk)
                    }
                    if showsVAT {
                        field("form.vat") { vatPicker }
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
            .navigationTitle(isEditing ? "form.title.edit" : "form.title.new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onChange(of: amountText) { _, text in draft.amount = MoneyParser.parse(text) }
            .onChange(of: draft.space) { _, space in spaceChanged(to: space) }
            .onAppear {
                if !isEditing {
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
            Text("form.amount")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
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
                    }
                }
            }
            if let vat = draft.vatAmount {
                Text("form.vat.included \(vat.formatted(.currency(code: "EUR")))")
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
        divider: Bool = true,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            HairlineDivider()
            Text(label)
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(.bottom, BifazSpacing.l)
    }

    // MARK: Actions

    /// Keeps the category and VAT consistent with the chosen space.
    private func spaceChanged(to space: Space) {
        if let category = draft.category, category.space != space { draft.category = nil }
        if space == .pro, isVATRegistered {
            if draft.vatRate == nil, !isEditing || expense?.space != .pro { draft.vatRate = .standard }
        } else {
            draft.vatRate = nil
        }
    }

    /// Prefills space and category from what Bifaz learned about this merchant.
    private func applyMemory(for merchant: String) {
        guard let rule = MerchantMemory.suggestion(for: merchant, in: context) else { return }
        draft.space = rule.space
        if let category = rule.category { draft.category = category }
    }

    private func save() {
        do {
            if let expense {
                try ExpenseService.update(expense, with: draft, in: context)
            } else {
                try ExpenseService.create(from: draft, in: context)
            }
            savedCount += 1
            dismiss()
        } catch {
            Log.app.error("Saving expense failed: \(String(describing: error), privacy: .public)")
            saveError = error
        }
    }

    private func delete() {
        guard let expense else { return }
        do {
            try ExpenseService.delete(expense, in: context)
            dismiss()
            onDeleted()
        } catch {
            Log.app.error("Deleting expense failed: \(String(describing: error), privacy: .public)")
            saveError = error
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
