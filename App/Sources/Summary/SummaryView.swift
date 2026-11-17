import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Summary tab: this month's total for the selected space, the Pro/Personal
/// split, VAT paid, what needs attention and the latest expenses. Charts and
/// month-over-month comparison arrive in phase 3.
struct SummaryView: View {
    @Binding var spaceFilter: SpaceFilter

    var body: some View {
        NavigationStack {
            SummaryContent(spaceFilter: $spaceFilter, month: ExpenseGrouping.monthInterval())
                .navigationTitle("tab.summary")
                .navigationDestination(for: PersistentIdentifier.self) { id in
                    ExpenseDestination(id: id)
                }
                .bifazScreen()
        }
    }
}

/// Resolves an expense id pushed on a navigation stack.
struct ExpenseDestination: View {
    let id: PersistentIdentifier
    @Environment(\.modelContext) private var context

    var body: some View {
        if let expense = context.model(for: id) as? Expense, !expense.isDeleted {
            ExpenseDetailView(expense: expense)
        }
    }
}

private struct SummaryContent: View {
    @Binding var spaceFilter: SpaceFilter
    let month: DateInterval

    @Environment(AppNavigation.self) private var navigation
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @Query private var monthExpenses: [Expense]
    @Query private var toReview: [Expense]
    @Query private var latest: [Expense]

    init(spaceFilter: Binding<SpaceFilter>, month: DateInterval) {
        _spaceFilter = spaceFilter
        self.month = month
        _monthExpenses = Query(ExpenseFilter(dateInterval: month).fetchDescriptor)
        let pending = ExpenseStatus.receiptPending.rawValue
        let review = ExpenseStatus.needsReview.rawValue
        _toReview = Query(
            filter: #Predicate<Expense> { $0.statusRawValue == pending || $0.statusRawValue == review },
            sort: \Expense.date, order: .reverse
        )
        var latestDescriptor = ExpenseFilter().fetchDescriptor
        latestDescriptor.fetchLimit = 30
        _latest = Query(latestDescriptor)
    }

    private var totals: ExpenseTotals { ExpenseTotals(monthExpenses.filter { spaceFilter.includes($0.space) }) }
    private var reviewItems: [Expense] { toReview.filter { spaceFilter.includes($0.space) } }
    private var latestItems: [Expense] { Array(latest.filter { spaceFilter.includes($0.space) }.prefix(5)) }
    private var hasAnyExpense: Bool { !latest.isEmpty }

    private var monthName: String {
        month.start.formatted(Date.FormatStyle(capitalizationContext: .middleOfSentence).month(.wide))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SpaceSelector(selection: $spaceFilter)
                    .padding(.bottom, BifazSpacing.xl)

                header

                if !hasAnyExpense {
                    EmptyStateView(
                        title: "summary.empty.title",
                        message: "summary.empty.message",
                        primaryAction: .init("action.addExpense") { navigation.addExpense(filter: spaceFilter) }
                    )
                    .padding(.top, BifazSpacing.xxl)
                } else {
                    if spaceFilter.includes(.pro), isVATRegistered, totals.proVAT > 0 {
                        StatCard(title: "summary.vatPaid", amount: totals.proVAT, accent: .bifazPro)
                            .padding(.top, BifazSpacing.xl)
                    }
                    if !reviewItems.isEmpty {
                        section("summary.toReview", expenses: Array(reviewItems.prefix(5)))
                    }
                    section("summary.latest", expenses: latestItems)
                    if !latestItems.isEmpty {
                        Button("summary.seeAll") { navigation.selectedTab = .expenses }
                            .buttonStyle(.bifazSecondary)
                            .padding(.top, BifazSpacing.s)
                    }
                }
            }
            .padding(.horizontal, BifazSpacing.screen)
            .padding(.bottom, BifazSpacing.xxxl * 2)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("summary.spentIn \(monthName)")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
            AmountView(totals.total, style: .hero, tint: totals.total > 0 ? .bifazInk : .bifazInkSecondary)
                .padding(.top, BifazSpacing.xxs)
                .contentTransition(.numericText())
            SpaceSplitBar(
                pro: spaceFilter.includes(.pro) ? totals.pro : 0,
                personal: spaceFilter.includes(.personal) ? totals.personal : 0
            )
            .padding(.top, BifazSpacing.s)
        }
        .accessibilityElement(children: .combine)
    }

    private func section(_ title: LocalizedStringResource, expenses: [Expense]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title)
                .padding(.top, BifazSpacing.xxl)
                .padding(.bottom, BifazSpacing.xxs)
            if expenses.isEmpty {
                Text("summary.latest.empty")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
                    .padding(.vertical, BifazSpacing.s)
            }
            ForEach(Array(expenses.enumerated()), id: \.element.persistentModelID) { index, expense in
                if index > 0 { HairlineDivider(leadingInset: BifazSpacing.xxxl + BifazSpacing.xxs) }
                NavigationLink(value: expense.persistentModelID) {
                    ExpenseRow(expense)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Light") {
    SummaryView(spaceFilter: .constant(.all))
        .modelContainer(PreviewContainer.sample)
        .environment(AppNavigation())
}

#Preview("Dark") {
    SummaryView(spaceFilter: .constant(.pro))
        .modelContainer(PreviewContainer.sample)
        .environment(AppNavigation())
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    SummaryView(spaceFilter: .constant(.all))
        .modelContainer(PreviewContainer.empty)
        .environment(AppNavigation())
        .dynamicTypeSize(.accessibility3)
}
