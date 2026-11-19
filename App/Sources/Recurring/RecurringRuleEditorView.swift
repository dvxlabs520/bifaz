import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Sheet to create or edit a recurring expense. New: blank (starts today) or
/// from a template (the "Repeat this expense" case). Editing changes future
/// charges only, and offers Delete.
struct RecurringRuleEditorView: View {
    private let rule: RecurringRule?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var draft: ExpenseDraft
    @State private var amountText: String
    @State private var frequency: RecurrenceFrequency
    @State private var startDate: Date
    @State private var hasEnd: Bool
    @State private var endDate: Date
    @State private var isConfirmingDelete = false
    @State private var saveError: Error?
    @State private var saved = false
    @FocusState private var amountFocused: Bool

    private static let amountInputStyle = Decimal.FormatStyle.number.precision(.fractionLength(2)).grouping(.never)

    /// "€" as the current locale writes it.
    private static let currencySymbol: String = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.currencySymbol
    }()

    /// The template to repeat an expense: same values, starting one period after
    /// its date (same day next month by default).
    static func template(repeating draft: ExpenseDraft, frequency: RecurrenceFrequency = .monthly,
                         calendar: Calendar = .current) -> RecurringService.Template {
        RecurringService.Template.repeating(draft, frequency: frequency, calendar: calendar)
    }

    init(rule: RecurringRule? = nil, template: RecurringService.Template? = nil) {
        self.rule = rule
        let source = rule.map(RecurringService.Template.init(rule:)) ?? template
        let draft = source?.draft ?? ExpenseDraft()
        _draft = State(initialValue: draft)
        _amountText = State(initialValue: draft.amount.map { $0.formatted(Self.amountInputStyle) } ?? "")
        _frequency = State(initialValue: source?.frequency ?? .monthly)
        let start = source?.startDate ?? .now
        _startDate = State(initialValue: start)
        _hasEnd = State(initialValue: source?.endDate != nil)
        _endDate = State(initialValue: source?.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: start) ?? start)
    }

    private var isEditing: Bool { rule != nil }
    private var showsVAT: Bool { isVATRegistered && draft.space == .pro }
    private var spaceCategories: [ExpenseCategory] { categories.filter { $0.space == draft.space } }
    private var amountIsInvalid: Bool { !amountText.isEmpty && MoneyParser.parse(amountText) == nil }

    private var template: RecurringService.Template {
        RecurringService.Template(draft: draft, frequency: frequency, startDate: startDate, endDate: hasEnd ? endDate : nil)
    }

    private var validationError: RecurringService.ValidationError? { template.validate() }
    private var canSave: Bool { validationError == nil && !saved }

    /// The next three charges, from the start (or today when it is already past).
    private var upcoming: [Date] {
        let calendar = Calendar.current
        let from = max(calendar.startOfDay(for: startDate), calendar.startOfDay(for: .now))
        let through = calendar.date(byAdding: .year, value: 3, to: from) ?? from
        return Array(RecurrenceCalendar.occurrences(
            start: startDate, end: hasEnd ? endDate : nil, frequency: frequency,
            from: from, through: through, calendar: calendar, limit: 3
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    amountSection
                    field("recurring.editor.space") { spacePicker }
                    field("recurring.editor.category") { categoryPicker }
                    field("recurring.editor.merchant") { merchantField }
                    if showsVAT {
                        field("recurring.editor.vat") { vatPicker }
                    }
                    if draft.space == .pro {
                        field("recurring.editor.client") { TagPicker(kind: .client, selection: $draft.client) }
                        field("recurring.editor.project") { TagPicker(kind: .project, selection: $draft.project) }
                    }
                    field("recurring.editor.frequency") { frequencyPicker }
                    field("recurring.editor.start") {
                        DatePicker(selection: $startDate, displayedComponents: .date) {
                            Text("recurring.editor.start", tableName: "Recurring")
                        }
                        .labelsHidden()
                        .tint(.bifazInk)
                    }
                    field("recurring.editor.end") { endSection }
                    upcomingCaption
                    if let message = errorMessage {
                        message
                            .font(.bifazCaption)
                            .foregroundStyle(.bifazError)
                            .padding(.top, BifazSpacing.s)
                            .accessibilityIdentifier("ui.ruleError")
                    }
                    if isEditing {
                        Text("recurring.editor.futureOnly", tableName: "Recurring")
                            .font(.bifazCaption)
                            .foregroundStyle(.bifazInkSecondary)
                            .padding(.top, BifazSpacing.l)
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label {
                                Text("recurring.editor.delete", tableName: "Recurring")
                            } icon: {
                                BifazIconView(.trash, size: 18)
                            }
                        }
                        .buttonStyle(.bifazSecondary)
                        .foregroundStyle(.bifazError)
                        .accessibilityIdentifier("ui.ruleDelete")
                        .padding(.top, BifazSpacing.l)
                    }
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.bottom, BifazSpacing.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.bifazPaper)
            .navigationTitle(
                isEditing
                    ? Text("recurring.editor.title.edit", tableName: "Recurring")
                    : Text("recurring.editor.title.new", tableName: "Recurring")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        BifazIconView(.close, size: 18)
                    }
                    .accessibilityLabel(Text("recurring.editor.close", tableName: "Recurring"))
                    .accessibilityIdentifier("ui.ruleClose")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("recurring.editor.save", tableName: "Recurring")
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier("ui.ruleSave")
                }
            }
            .onChange(of: amountText) { _, text in draft.amount = MoneyParser.parse(text) }
            .onChange(of: draft.space) { _, space in spaceChanged(to: space) }
            .onAppear {
                if !isEditing {
                    spaceChanged(to: draft.space)
                    if draft.amount == nil { amountFocused = true }
                }
            }
            .confirmationDialog(
                Text("recurring.delete.title", tableName: "Recurring"),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(role: .destructive, action: delete) {
                    Text("recurring.delete.action", tableName: "Recurring")
                }
                .accessibilityIdentifier("ui.ruleDeleteConfirm")
            } message: {
                Text("recurring.delete.message", tableName: "Recurring")
            }
            .sensoryFeedback(.success, trigger: saved)
        }
        .presentationBackground(Color.bifazPaper)
    }

    // MARK: Sections

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            Text("recurring.editor.amount", tableName: "Recurring")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
                TextField(text: $amountText, prompt: Text(verbatim: Decimal(0).formatted(Self.amountInputStyle))) {
                    Text("recurring.editor.amount", tableName: "Recurring")
                }
                .font(.bifazAmountHero)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .accessibilityIdentifier("ui.ruleAmount")
                .foregroundStyle(.bifazInk)
                Text(verbatim: Self.currencySymbol)
                    .font(.bifazAmountHero)
                    .foregroundStyle(.bifazInkSecondary)
                    .accessibilityHidden(true)
            }
            if amountIsInvalid {
                Text("recurring.editor.amount.invalid", tableName: "Recurring")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazError)
            }
        }
        .padding(.vertical, BifazSpacing.l)
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
        TextField(text: $draft.merchant) {
            Text("recurring.editor.merchant.placeholder", tableName: "Recurring")
        }
        .font(.bifazBody)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .accessibilityIdentifier("ui.ruleMerchant")
    }

    private var vatPicker: some View {
        FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
            ForEach(VATRate.allCases) { rate in
                FilterChip(LocalizedStringResource(stringLiteral: rate.percentText), isSelected: draft.vatRate == rate) {
                    draft.vatRate = draft.vatRate == rate ? nil : rate
                }
            }
        }
    }

    private var frequencyPicker: some View {
        FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
            ForEach(RecurrenceFrequency.allCases, id: \.self) { option in
                FilterChip(option.title, isSelected: frequency == option) {
                    frequency = option
                }
                .accessibilityIdentifier("ui.ruleFrequency.\(option.rawValue)")
            }
        }
    }

    private var endSection: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            Toggle(isOn: $hasEnd) {
                Text("recurring.editor.end", tableName: "Recurring")
                    .font(.bifazBody)
            }
            .tint(.bifazInk)
            .accessibilityIdentifier("ui.ruleEndToggle")
            if hasEnd {
                DatePicker(selection: $endDate, displayedComponents: .date) {
                    Text("recurring.editor.end", tableName: "Recurring")
                }
                .labelsHidden()
                .tint(.bifazInk)
            }
        }
    }

    @ViewBuilder
    private var upcomingCaption: some View {
        let dates = upcoming
        Group {
            if dates.isEmpty {
                Text("recurring.editor.upcoming.none", tableName: "Recurring")
            } else {
                let list = dates.map { $0.formatted(.dateTime.day().month(.abbreviated)) }.joined(separator: ", ")
                Text("recurring.editor.upcoming \(list)", tableName: "Recurring")
            }
        }
        .font(.bifazCaption)
        .foregroundStyle(.bifazInkSecondary)
        .accessibilityIdentifier("ui.ruleUpcoming")
    }

    private func field(_ label: String.LocalizationValue, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            HairlineDivider()
            Text(LocalizedStringResource(label, table: "Recurring"))
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(.bottom, BifazSpacing.l)
    }

    // MARK: Errors

    private var errorMessage: Text? {
        if let saveError {
            return message(for: saveError)
        }
        switch validationError {
        case .endBeforeStart: return message(for: RecurringService.ValidationError.endBeforeStart)
        case .foreignCurrency: return message(for: RecurringService.ValidationError.foreignCurrency)
        case .amountNotPositive:
            // Only once the user typed something; an empty form is not an error.
            return amountText.isEmpty || amountIsInvalid ? nil : message(for: RecurringService.ValidationError.amountNotPositive)
        case nil: return nil
        }
    }

    private func message(for error: Error) -> Text {
        switch error as? RecurringService.ValidationError {
        case .amountNotPositive: Text("recurring.validation.amountNotPositive", tableName: "Recurring")
        case .endBeforeStart: Text("recurring.validation.endBeforeStart", tableName: "Recurring")
        case .foreignCurrency: Text("recurring.validation.foreignCurrency", tableName: "Recurring")
        case nil: Text("recurring.validation.generic", tableName: "Recurring")
        }
    }

    // MARK: Actions

    /// Keeps the category, VAT, client and project consistent with the chosen space.
    private func spaceChanged(to space: Space) {
        if let category = draft.category, category.space != space { draft.category = nil }
        if space == .pro, isVATRegistered {
            if draft.vatRate == nil, !isEditing || rule?.space != .pro { draft.vatRate = .standard }
        } else {
            draft.vatRate = nil
        }
        if space != .pro {
            draft.client = nil
            draft.project = nil
        }
    }

    private func save() {
        do {
            if let rule {
                try RecurringService.update(rule, with: template, in: context)
            } else {
                try RecurringService.create(template, in: context)
            }
            // A rule starting today (or earlier) gets its expenses now, not at the next launch.
            _ = try? RecurringService.generateDue(in: context)
            Task { await NotificationScheduler.shared.reschedule(in: context) }
            saved = true
            dismiss()
        } catch {
            Log.app.error("Saving recurring rule failed: \(String(describing: error), privacy: .public)")
            context.rollback()
            saveError = error
        }
    }

    private func delete() {
        guard let rule else { return }
        do {
            try RecurringService.delete(rule, in: context)
            dismiss()
        } catch {
            Log.app.error("Deleting recurring rule failed: \(String(describing: error), privacy: .public)")
            context.rollback()
            saveError = error
        }
    }
}

extension RecurrenceFrequency {
    var title: LocalizedStringResource {
        switch self {
        case .weekly: LocalizedStringResource("recurring.frequency.weekly", table: "Recurring")
        case .monthly: LocalizedStringResource("recurring.frequency.monthly", table: "Recurring")
        case .quarterly: LocalizedStringResource("recurring.frequency.quarterly", table: "Recurring")
        case .yearly: LocalizedStringResource("recurring.frequency.yearly", table: "Recurring")
        }
    }
}

// MARK: - Previews

private enum RecurringEditorPreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            try CategorySeeder.seedIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()

    static var template: RecurringService.Template {
        let start = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 31)) ?? .now
        return .init(draft: ExpenseDraft(amount: 71.99, merchant: "Freebox"), frequency: .monthly, startDate: start)
    }
}

#Preview("Light") {
    RecurringRuleEditorView(template: RecurringEditorPreviewData.template)
        .modelContainer(RecurringEditorPreviewData.container)
}

#Preview("Dark") {
    RecurringRuleEditorView(template: RecurringEditorPreviewData.template)
        .modelContainer(RecurringEditorPreviewData.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    RecurringRuleEditorView()
        .modelContainer(RecurringEditorPreviewData.container)
        .dynamicTypeSize(.accessibility3)
}
