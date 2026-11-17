import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Every budget, grouped by space, with the way to add, edit and delete them.
/// Pushed inside an existing NavigationStack.
struct BudgetsView: View {
    private enum EditorTarget: Identifiable {
        case new
        case edit(Budget)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let budget): budget.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query private var categories: [ExpenseCategory]
    @State private var editor: EditorTarget?
    @State private var pendingDeletion: Budget?
    @State private var saveFailed = false
    @State private var deletions = 0

    private var hasFreeCategory: Bool {
        categories.contains { ($0.budgets ?? []).isEmpty }
    }

    /// Budgets of one space, by category name.
    private func budgets(in space: Space) -> [Budget] {
        budgets
            .filter { $0.category?.space == space }
            .sorted { ($0.category?.displayName ?? "").localizedCaseInsensitiveCompare($1.category?.displayName ?? "") == .orderedAscending }
    }

    var body: some View {
        Group {
            if budgets.isEmpty {
                ScrollView { emptyState }
            } else {
                list
            }
        }
        .background(Color.bifazPaper)
        .navigationTitle(Text("budgets.title", tableName: "Budgets"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { target in
            switch target {
            case .new: BudgetEditorView()
            case .edit(let budget): BudgetEditorView(budget: budget)
            }
        }
        .confirmationDialog(
            Text("budgets.delete.title \(pendingDeletion?.category?.displayName ?? "")", tableName: "Budgets"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { budget in
            Button(role: .destructive) {
                delete(budget)
            } label: {
                Text("budgets.delete.action", tableName: "Budgets")
            }
        } message: { _ in
            Text("budgets.delete.message", tableName: "Budgets")
        }
        .alert(Text("budgets.error.title", tableName: "Budgets"), isPresented: $saveFailed) {
            Button {} label: { Text("budgets.error.ok", tableName: "Budgets") }
        }
        .sensoryFeedback(.warning, trigger: deletions)
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            Text("budgets.empty.title", tableName: "Budgets")
                .font(.bifazTitle)
                .foregroundStyle(Color.bifazInk)
                .accessibilityAddTraits(.isHeader)
            Text("budgets.empty.message", tableName: "Budgets")
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            addControl
                .padding(.top, BifazSpacing.xs)
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BifazSpacing.screen)
        .padding(.top, BifazSpacing.xl)
    }

    // MARK: List

    private var list: some View {
        VStack(spacing: 0) {
            List {
                ForEach(Space.allCases) { space in
                    let rows = budgets(in: space)
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows) { budget in row(budget, space: space) }
                        } header: {
                            spaceHeader(space)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            addControl
                .padding(.horizontal, BifazSpacing.screen)
                .padding(.vertical, BifazSpacing.s)
        }
    }

    private func spaceHeader(_ space: Space) -> some View {
        HStack(spacing: BifazSpacing.xs) {
            BifazIconView(space.icon, size: 16, relativeTo: .subheadline)
                .foregroundStyle(space.color)
            Text(space.title)
                .font(.bifazSubheadline)
                .foregroundStyle(Color.bifazInkSecondary)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func row(_ budget: Budget, space: Space) -> some View {
        let amount = budget.monthlyAmount.formatted(.currency(code: "EUR"))
        return Button {
            editor = .edit(budget)
        } label: {
            HStack(spacing: BifazSpacing.m) {
                CategoryIcon(icon: budget.category?.icon ?? .other, tint: space.color, background: space.tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text(budget.category?.displayName ?? "")
                        .font(.bifazBody)
                        .foregroundStyle(Color.bifazInk)
                    Text("budgets.row.amount \(amount)", tableName: "Budgets")
                        .font(.bifazCaption.monospacedDigit())
                        .foregroundStyle(Color.bifazInkSecondary)
                }
                Spacer(minLength: BifazSpacing.xs)
                BifazIconView(.chevronRight, size: 14, relativeTo: .body)
                    .foregroundStyle(Color.bifazInkSecondary)
            }
            .padding(.vertical, BifazSpacing.xs)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("budgets.row.hint", tableName: "Budgets"))
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.bifazPaper)
        .listRowSeparatorTint(.bifazHairline)
        .listRowInsets(EdgeInsets(
            top: BifazSpacing.xxs, leading: BifazSpacing.screen,
            bottom: BifazSpacing.xxs, trailing: BifazSpacing.screen
        ))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeletion = budget
            } label: {
                Text("budgets.delete.action", tableName: "Budgets")
            }
        }
    }

    /// The add button, or a note when every category has a budget.
    @ViewBuilder
    private var addControl: some View {
        if hasFreeCategory {
            Button {
                editor = .new
            } label: {
                Text("budgets.add", tableName: "Budgets")
            }
            .buttonStyle(.bifazPrimary)
            .accessibilityIdentifier("ui.budgetAdd")
        } else if !categories.isEmpty {
            Text("budgets.allCovered", tableName: "Budgets")
                .font(.bifazCaption)
                .foregroundStyle(Color.bifazInkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func delete(_ budget: Budget) {
        do {
            try BudgetService.delete(budget, in: modelContext)
            deletions += 1
        } catch {
            Log.app.error("Deleting budget failed: \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            saveFailed = true
        }
    }
}

// MARK: - Previews

private enum BudgetsPreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            try SampleData.insert(into: context)
            let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
            for (index, category) in categories.prefix(3).enumerated() {
                context.insert(Budget(category: category, monthlyAmount: Decimal(150 + index * 100)))
            }
            if let personal = categories.first(where: { $0.space == .personal }) {
                context.insert(Budget(category: personal, monthlyAmount: 400))
            }
            try context.save()
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}

#Preview("Light") {
    NavigationStack { BudgetsView() }
        .modelContainer(BudgetsPreviewData.container)
}

#Preview("Dark") {
    NavigationStack { BudgetsView() }
        .modelContainer(BudgetsPreviewData.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    NavigationStack { BudgetsView() }
        .modelContainer(BudgetsPreviewData.container)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Empty") {
    NavigationStack { BudgetsView() }
        .modelContainer(PreviewContainer.sample)
}
