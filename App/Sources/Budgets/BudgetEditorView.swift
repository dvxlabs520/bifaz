import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Sheet to set the monthly limit of a category: new budget (pick a category
/// that has none) or edit one (category fixed, delete available).
struct BudgetEditorView: View {
    private let budget: Budget?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.createdAt)])
    private var allCategories: [ExpenseCategory]
    @State private var selected: ExpenseCategory?
    @State private var amountText: String
    @State private var confirmingDelete = false
    @State private var saved = false
    @State private var saveFailed = false
    @FocusState private var amountFocused: Bool

    private static let amountInputStyle = Decimal.FormatStyle.number.precision(.fractionLength(2)).grouping(.never)

    /// "€" as the current locale writes it.
    private static let currencySymbol: String = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.currencySymbol
    }()

    init(budget: Budget? = nil, preselectedCategory: ExpenseCategory? = nil) {
        self.budget = budget
        _selected = State(initialValue: budget?.category ?? preselectedCategory)
        _amountText = State(initialValue: budget.map { $0.monthlyAmount.formatted(Self.amountInputStyle) } ?? "")
    }

    private var amount: Decimal? { MoneyParser.parse(amountText) }

    private var amountIsValid: Bool {
        guard let amount else { return false }
        return amount > 0 && amount <= MoneyParser.maximum
    }

    private var amountIsInvalid: Bool { !amountText.isEmpty && !amountIsValid }

    private var canSave: Bool { selected != nil && amountIsValid && !saved }

    /// Categories that can still get a budget (the chosen one stays listed).
    private var available: [ExpenseCategory] {
        allCategories.filter {
            ($0.budgets ?? []).isEmpty || $0.persistentModelID == selected?.persistentModelID
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BifazSpacing.xl) {
                    categorySection
                    amountSection
                    if budget != nil { deleteButton }
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.vertical, BifazSpacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.bifazPaper)
            .navigationTitle(
                budget == nil
                    ? Text("budgets.editor.title.new", tableName: "Budgets")
                    : Text("budgets.editor.title.edit", tableName: "Budgets")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        BifazIconView(.close)
                    }
                    .accessibilityLabel(Text("budgets.editor.close", tableName: "Budgets"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("budgets.editor.save", tableName: "Budgets")
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("ui.budgetSave")
                }
            }
            .confirmationDialog(
                Text("budgets.delete.title \(selected?.displayName ?? "")", tableName: "Budgets"),
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    delete()
                } label: {
                    Text("budgets.delete.action", tableName: "Budgets")
                }
            } message: {
                Text("budgets.delete.message", tableName: "Budgets")
            }
            .alert(Text("budgets.error.title", tableName: "Budgets"), isPresented: $saveFailed) {
                Button {} label: { Text("budgets.error.ok", tableName: "Budgets") }
            }
            .sensoryFeedback(.success, trigger: saved)
            .onAppear {
                if budget == nil, selected != nil { amountFocused = true }
            }
        }
        .presentationBackground(Color.bifazPaper)
    }

    // MARK: Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            SectionHeader(LocalizedStringResource("budgets.editor.category", table: "Budgets"))
            if let budget, let category = budget.category {
                HStack(spacing: BifazSpacing.s) {
                    CategoryIcon(icon: category.icon, tint: category.space.color, background: category.space.tint)
                    Text(category.displayName)
                        .font(.bifazBody)
                        .foregroundStyle(Color.bifazInk)
                }
                .accessibilityElement(children: .combine)
            } else if available.isEmpty {
                Text("budgets.allCovered", tableName: "Budgets")
                    .font(.bifazCaption)
                    .foregroundStyle(Color.bifazInkSecondary)
            } else {
                ForEach(Space.allCases) { space in
                    let options = available.filter { $0.space == space }
                    if !options.isEmpty { chips(options, space: space) }
                }
            }
        }
    }

    private func chips(_ options: [ExpenseCategory], space: Space) -> some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            HStack(spacing: BifazSpacing.xs) {
                BifazIconView(space.icon, size: 16, relativeTo: .subheadline)
                    .foregroundStyle(space.color)
                Text(space.title)
                    .font(.bifazSubheadline)
                    .foregroundStyle(Color.bifazInkSecondary)
            }
            .accessibilityElement(children: .combine)
            FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
                ForEach(options) { category in
                    let isSelected = category.persistentModelID == selected?.persistentModelID
                    Button {
                        selected = category
                        amountFocused = true
                    } label: {
                        CategoryChip(category.displayName, icon: category.icon, tint: space.color, isSelected: isSelected)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isSelected)
                    .accessibilityLabel(Text(verbatim: category.displayName))
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    .accessibilityIdentifier("ui.budgetCategory")
                }
            }
        }
    }

    // MARK: Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            Text("budgets.editor.amount", tableName: "Budgets")
                .font(.bifazCaption)
                .foregroundStyle(Color.bifazInkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
                TextField(
                    text: $amountText,
                    prompt: Text(verbatim: Decimal(0).formatted(Self.amountInputStyle))
                ) {
                    Text("budgets.editor.amount", tableName: "Budgets")
                }
                .font(.bifazAmountHero)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .foregroundStyle(Color.bifazInk)
                .accessibilityIdentifier("ui.budgetAmount")
                Text(verbatim: Self.currencySymbol)
                    .font(.bifazAmountHero)
                    .foregroundStyle(Color.bifazInkSecondary)
                    .accessibilityHidden(true)
            }
            Text("budgets.perMonth", tableName: "Budgets")
                .font(.bifazCaption)
                .foregroundStyle(Color.bifazInkSecondary)
            if amountIsInvalid {
                HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
                    BifazIconView(.warning, size: 14, relativeTo: .footnote)
                    Text("budgets.editor.amount.invalid", tableName: "Budgets")
                }
                .font(.bifazCaption)
                .foregroundStyle(Color.bifazError)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            HStack(spacing: BifazSpacing.xs) {
                BifazIconView(.trash, size: 18, relativeTo: .body)
                Text("budgets.delete.action", tableName: "Budgets")
            }
            .font(.bifazHeadline)
            .foregroundStyle(Color.bifazError)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func save() {
        guard canSave, let category = selected, let amount else { return }
        do {
            try BudgetService.setBudget(amount, for: category, in: modelContext)
            finish()
        } catch {
            Log.app.error("Saving budget failed: \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            saveFailed = true
        }
    }

    private func delete() {
        guard let budget else { return }
        do {
            try BudgetService.delete(budget, in: modelContext)
            finish()
        } catch {
            Log.app.error("Deleting budget failed: \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            saveFailed = true
        }
    }

    private func finish() {
        saved = true
        Task {
            // Let the haptic fire before the sheet goes away.
            try? await Task.sleep(for: .milliseconds(250))
            dismiss()
        }
    }
}

// MARK: - Previews

private enum EditorPreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            try CategorySeeder.seedIfNeeded(in: context)
            let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
            if let first = categories.first { context.insert(Budget(category: first, monthlyAmount: 250)) }
            try context.save()
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()

    @MainActor static var existing: Budget? {
        try? container.mainContext.fetch(FetchDescriptor<Budget>()).first
    }
}

#Preview("Light") {
    BudgetEditorView()
        .modelContainer(EditorPreviewData.container)
}

#Preview("Dark") {
    BudgetEditorView()
        .modelContainer(EditorPreviewData.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    BudgetEditorView()
        .modelContainer(EditorPreviewData.container)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Edit") {
    BudgetEditorView(budget: EditorPreviewData.existing)
        .modelContainer(EditorPreviewData.container)
}
