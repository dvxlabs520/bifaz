import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// The grouped expense history: one section per month, newest first.
struct ExpenseListView: View {
    let filter: ExpenseFilter
    let onClearFilters: () -> Void

    var body: some View {
        // Re-created when the filter changes so the query follows it.
        ExpenseListContent(filter: filter, onClearFilters: onClearFilters)
            .id(filter.fetchDescriptorIdentity)
    }
}

private extension ExpenseFilter {
    /// Changes whenever the store-side part of the query changes.
    var fetchDescriptorIdentity: String {
        "\(space.rawValue)|\(dateInterval?.start.timeIntervalSinceReferenceDate ?? 0)|\(dateInterval?.end.timeIntervalSinceReferenceDate ?? 0)"
    }

    /// No refinement and no search: only the space filter applies.
    var isUnrefined: Bool {
        activeRefinementCount == 0 && searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

private struct ExpenseListContent: View {
    let filter: ExpenseFilter
    let onClearFilters: () -> Void

    @Query private var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(AppNavigation.self) private var navigation
    @State private var pendingDeletion: Expense?
    @State private var deletionFailed = false

    private static let monthStyle = Date.FormatStyle.dateTime.month(.wide).year()

    init(filter: ExpenseFilter, onClearFilters: @escaping () -> Void) {
        self.filter = filter
        self.onClearFilters = onClearFilters
        _expenses = Query(filter.fetchDescriptor)
    }

    var body: some View {
        let groups = ExpenseGrouping.byMonth(expenses.filter { filter.matches($0, categoryName: { $0.displayName }) })
        Group {
            if groups.isEmpty {
                emptyState
            } else {
                list(groups)
            }
        }
        .navigationDestination(for: PersistentIdentifier.self) { id in
            if let expense = modelContext.model(for: id) as? Expense {
                ExpenseDetailView(expense: expense)
            }
        }
        .confirmationDialog(
            Text("history.delete.title", tableName: "History"),
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { expense in
            Button(role: .destructive) {
                delete(expense)
            } label: {
                Text("history.delete.confirm", tableName: "History")
            }
            Button(role: .cancel) {} label: {
                Text("history.delete.cancel", tableName: "History")
            }
        } message: { expense in
            DeleteExpenseMessage(merchant: expense.merchant)
        }
        .alert(
            Text("history.delete.failed", tableName: "History"),
            isPresented: $deletionFailed
        ) {
            Button(role: .cancel) {} label: {
                Text("history.delete.cancel", tableName: "History")
            }
        }
    }

    // MARK: List

    private func list(_ groups: [MonthGroup]) -> some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.expenses) { expense in
                        NavigationLink(value: expense.persistentModelID) {
                            ExpenseRow(expense)
                        }
                        .listRowBackground(Color.bifazPaper)
                        .listRowSeparatorTint(Color.bifazHairline)
                        .listRowInsets(EdgeInsets(
                            top: 0, leading: BifazSpacing.screen, bottom: 0, trailing: BifazSpacing.screen
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = expense
                            } label: {
                                Label {
                                    Text("history.delete.action", tableName: "History")
                                } icon: {
                                    BifazIcon.trash.image
                                }
                            }
                            .tint(.bifazError)
                        }
                    }
                } header: {
                    monthHeader(group)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bifazPaper)
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private func monthHeader(_ group: MonthGroup) -> some View {
        let title = Self.capitalized(group.month.formatted(Self.monthStyle.locale(locale)), locale: locale)
        let total = group.totals.total.formatted(.currency(code: "EUR").locale(locale))
        // Side by side normally; stacked at accessibility sizes so the month never hyphenates.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: BifazSpacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: BifazSpacing.xs))
        return layout {
            Text(verbatim: title)
                .font(.bifazSectionTitle)
                .foregroundStyle(Color.bifazInk)
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: BifazSpacing.xs) }
            AmountView(group.totals.total, style: .row, tint: .bifazInkSecondary)
        }
        .padding(.horizontal, BifazSpacing.screen)
        .padding(.top, BifazSpacing.m)
        .padding(.bottom, BifazSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bifazPaper)
        .textCase(nil)
        .listRowInsets(EdgeInsets())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(title), \(total)"))
        .accessibilityAddTraits(.isHeader)
    }

    private static func capitalized(_ text: String, locale: Locale) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased(with: locale) + text.dropFirst()
    }

    // MARK: Empty states

    private var emptyState: some View {
        ScrollView {
            Group {
                if filter.isUnrefined {
                    EmptyStateView(
                        title: "expenses.empty.title",
                        message: "expenses.empty.message",
                        primaryAction: .init("action.addExpense") {
                            navigation.addExpense(filter: filter.space)
                        }
                    )
                } else {
                    EmptyStateView(
                        title: LocalizedStringResource("history.empty.noResults.title", table: "History"),
                        message: LocalizedStringResource("history.empty.noResults.message", table: "History"),
                        secondaryAction: .init(LocalizedStringResource("history.filter.clear", table: "History")) {
                            onClearFilters()
                        }
                    )
                }
            }
            .padding(.horizontal, BifazSpacing.screen)
            .padding(.top, BifazSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Deleting

    private func delete(_ expense: Expense) {
        pendingDeletion = nil
        do {
            try ExpenseService.delete(expense, in: modelContext)
        } catch {
            deletionFailed = true
        }
    }
}

#if DEBUG
/// Sample French data for previews of the history screens.
@MainActor
enum HistoryPreviewData {
    static func container() -> ModelContainer {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            let transport = ExpenseCategory(name: "Transport", iconName: "transport", space: .pro, sortOrder: 0)
            let software = ExpenseCategory(name: "Logiciels", iconName: "software", space: .pro, sortOrder: 1)
            let groceries = ExpenseCategory(name: "Courses", iconName: "groceries", space: .personal, sortOrder: 0)
            let leisure = ExpenseCategory(name: "Loisirs", iconName: "leisure", space: .personal, sortOrder: 1)
            for category in [transport, software, groceries, leisure] { context.insert(category) }
            let calendar = Calendar.current
            func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now }
            let samples: [Expense] = [
                Expense(amount: 42.80, date: day(1), merchant: "Monoprix", space: .personal, category: groceries),
                Expense(
                    amount: 128.40, date: day(3), merchant: "SNCF", space: .pro, category: transport,
                    vatRate: Decimal(string: "0.10"), vatAmount: 11.67, note: "Aller-retour Lyon", status: .receiptPending
                ),
                Expense(
                    amount: 65.99, date: day(9), merchant: "Adobe", space: .pro, category: software,
                    vatRate: Decimal(string: "0.20"), vatAmount: 11.00, source: .recurring
                ),
                Expense(amount: 18.50, date: day(35), merchant: "Cinéma Pathé", space: .personal, category: leisure),
                Expense(amount: 4.30, date: day(40), merchant: "Boulangerie Paul", space: .personal),
                Expense(amount: 312.00, date: day(70), merchant: "Fnac", space: .pro, category: software, source: .scanner),
            ]
            for expense in samples { context.insert(expense) }
            try context.save()
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }
}

private struct ListPreview: View {
    let container = HistoryPreviewData.container()
    var filter = ExpenseFilter()
    @State private var navigation = AppNavigation()

    var body: some View {
        NavigationStack {
            ExpenseListView(filter: filter, onClearFilters: {})
                .navigationTitle("tab.expenses")
                .background(Color.bifazPaper)
        }
        .modelContainer(container)
        .environment(navigation)
    }
}

#Preview("Light") {
    ListPreview()
}

#Preview("Dark") {
    ListPreview().preferredColorScheme(.dark)
}

#Preview("Large text") {
    ListPreview().dynamicTypeSize(.accessibility3)
}

#Preview("No results") {
    ListPreview(filter: ExpenseFilter(searchText: "zzz"))
}
#endif
