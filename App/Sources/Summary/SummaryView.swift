import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Summary tab: one month at a time for the selected space — total and change
/// against the previous month, split by category, six-month evolution, Pro VAT
/// by rate, budgets, what needs attention and the latest expenses.
///
/// The figures come from `SummaryLoader` (BifazKit), off the main thread, with
/// the same query and sums as the history.
struct SummaryView: View {
    @Binding var spaceFilter: SpaceFilter
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.summaryPath) {
            SummaryContent(spaceFilter: $spaceFilter)
                .navigationTitle("tab.summary")
                .navigationDestination(for: PersistentIdentifier.self) { id in
                    ExpenseDestination(id: id)
                }
                .navigationDestination(for: SummaryHistoryRoute.self) { route in
                    SummaryHistoryView(route: route)
                }
                .navigationDestination(for: SummaryRoute.self) { route in
                    switch route {
                    case .budgets: BudgetsView()
                    }
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

/// Other places the Summary opens (from a notification).
enum SummaryRoute: Hashable {
    case budgets
}

/// The history of one category (or of "No category") in one month and space.
struct SummaryHistoryRoute: Hashable {
    var month: DateInterval
    var space: SpaceFilter
    /// `nil`: expenses without a category.
    var categoryID: UUID?

    var filter: ExpenseFilter {
        ExpenseFilter(
            space: space,
            categoryIDs: categoryID.map { [$0] } ?? [],
            withoutCategory: categoryID == nil,
            dateInterval: month
        )
    }
}

private struct SummaryContent: View {
    @Binding var spaceFilter: SpaceFilter

    @Environment(\.modelContext) private var context
    @Environment(AppNavigation.self) private var navigation
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query private var toReview: [Expense]
    @Query private var latest: [Expense]

    @State private var month = ExpenseGrouping.monthInterval()
    @State private var result: SummaryResult?
    @State private var loader: SummaryLoader?
    /// Bumped on every save, so the loader drops its month cache.
    @State private var storeVersion = 0

    init(spaceFilter: Binding<SpaceFilter>) {
        _spaceFilter = spaceFilter
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

    private struct LoadKey: Equatable {
        var month: DateInterval
        var space: SpaceFilter
        var version: Int
    }

    /// The loaded summary, only when it is for what is on screen.
    private var summary: MonthSummary? {
        guard let summary = result?.summary, summary.month == month, summary.space == spaceFilter else { return nil }
        return summary
    }

    private var categoriesByID: [UUID: ExpenseCategory] {
        Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var reviewItems: [Expense] { toReview.filter { spaceFilter.includes($0.space) } }
    private var latestItems: [Expense] { Array(latest.filter { spaceFilter.includes($0.space) }.prefix(5)) }
    private var hasAnyExpense: Bool { !latest.isEmpty }
    private var isCurrentMonth: Bool { month.containsHalfOpen(.now) }

    private var canGoBack: Bool {
        guard let first = result?.firstMonth else { return false }
        return month.start > first.start
    }

    private func monthName(_ date: Date, context capitalization: FormatStyleCapitalizationContext = .middleOfSentence) -> String {
        date.formatted(Date.FormatStyle(capitalizationContext: capitalization).month(.wide))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SpaceSelector(selection: $spaceFilter)
                    .padding(.bottom, BifazSpacing.l)

                if !hasAnyExpense {
                    header(total: 0)
                    EmptyStateView(
                        title: "summary.empty.title",
                        message: "summary.empty.message",
                        primaryAction: .init("action.addExpense") { navigation.addExpense(filter: spaceFilter) }
                    )
                    .padding(.top, BifazSpacing.xxl)
                } else {
                    monthPicker
                        .padding(.bottom, BifazSpacing.m)
                    // Until the first load, a placeholder: never a false "0,00 €".
                    header(total: summary?.totals.total ?? result?.summary.totals.total)
                    // What asks for action first: to review, then budgets; then the analysis.
                    if !reviewItems.isEmpty {
                        section("summary.toReview", expenses: Array(reviewItems.prefix(5)))
                    }
                    if let summary {
                        BudgetSummarySection(
                            statuses: result?.budgets ?? [],
                            categories: categoriesByID,
                            isCurrentMonth: summary.isCurrentMonth
                        )
                        .padding(.top, BifazSpacing.xxl)
                        details(summary)
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
            .padding(.bottom, BifazSpacing.xxxl)
        }
        .task(id: LoadKey(month: month, space: spaceFilter, version: storeVersion)) { await load() }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            storeVersion += 1
        }
    }

    // MARK: Loading

    private func load() async {
        let loader = loader ?? SummaryLoader(modelContainer: context.container)
        self.loader = loader
        let key = LoadKey(month: month, space: spaceFilter, version: storeVersion)
        do {
            let clock = ContinuousClock()
            let started = clock.now
            let loaded = try await loader.load(month: key.month, space: key.space, version: key.version)
            let elapsed = started.duration(to: clock.now)
            #if DEBUG
            Log.app.notice("Summary loaded in \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public)")
            #endif
            guard !Task.isCancelled else { return }
            result = loaded
        } catch {
            Log.app.error("Summary failed to load: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Month

    private var monthPicker: some View {
        HStack(spacing: BifazSpacing.xs) {
            Button {
                step(-1)
            } label: {
                BifazIconView(.chevronDown, size: 20)
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoBack)
            .accessibilityLabel(Text("summary.month.previous"))
            .accessibilityIdentifier("ui.summaryMonthPrevious")

            Text(verbatim: month.start.formatted(Date.FormatStyle(capitalizationContext: .standalone).month(.wide).year()))
                .font(.bifazSectionTitle)
                .foregroundStyle(Color.bifazInk)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ui.summaryMonth")

            Button {
                step(1)
            } label: {
                BifazIconView(.chevronRight, size: 20)
                    .frame(width: 44, height: 44)
            }
            .disabled(isCurrentMonth)
            .accessibilityLabel(Text("summary.month.next"))
            .accessibilityIdentifier("ui.summaryMonthNext")
        }
        .foregroundStyle(Color.bifazInk)
        .buttonStyle(.plain)
        .background(Color.bifazSurfaceMuted, in: Capsule())
        .sensoryFeedback(.selection, trigger: month)
    }

    private func step(_ months: Int) {
        guard let date = Calendar.current.date(byAdding: .month, value: months, to: month.start) else { return }
        let next = ExpenseGrouping.monthInterval(containing: date)
        guard next.start <= ExpenseGrouping.monthInterval().start else { return }
        withAnimation(.snappy) { month = next }
    }

    // MARK: Header

    private func header(total: Decimal?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("summary.spentIn \(monthName(month.start))")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
            AmountView(total ?? 0, style: .hero, tint: (total ?? 0) > 0 ? .bifazInk : .bifazInkSecondary)
                .padding(.top, BifazSpacing.xxs)
                .contentTransition(.numericText())
                .redacted(reason: total == nil ? .placeholder : [])
            if let comparison = summary?.comparison {
                MonthComparisonView(
                    comparison: comparison,
                    previousMonth: Calendar.current.date(byAdding: .month, value: -1, to: month.start) ?? month.start
                )
                .padding(.top, BifazSpacing.xs)
            }
            if spaceFilter == .all, let totals = summary?.totals, totals.total > 0 {
                SpaceSplitBar(pro: totals.pro, personal: totals.personal)
                    .padding(.top, BifazSpacing.s)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ui.summaryHeader")
    }

    // MARK: Sections

    @ViewBuilder
    private func details(_ summary: MonthSummary) -> some View {
        if summary.categories.isEmpty {
            Text("summary.monthEmpty \(monthName(month.start))")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
                .padding(.top, BifazSpacing.m)
        } else {
            sectionTitle("summary.byCategory")
            CategoryBreakdownView(
                shares: summary.categories,
                categories: categoriesByID,
                tint: spaceFilter.color
            ) { categoryID in
                navigation.summaryPath.append(SummaryHistoryRoute(month: month, space: spaceFilter, categoryID: categoryID))
            }
        }

        sectionTitle("summary.evolution")
        EvolutionChart(bars: summary.evolution, space: spaceFilter, selectedMonth: month.start) { selected in
            let interval = ExpenseGrouping.monthInterval(containing: selected)
            guard interval.start <= ExpenseGrouping.monthInterval().start else { return }
            withAnimation(.snappy) { month = interval }
        }

        if isVATRegistered, let vat = summary.vat, vat.quarterVAT > 0 || summary.totals.pro > 0 {
            VATSummaryCard(vat: vat, month: month.start)
                .padding(.top, BifazSpacing.xxl)
        }
    }

    private func sectionTitle(_ title: LocalizedStringResource) -> some View {
        SectionHeader(title)
            .padding(.top, BifazSpacing.xxl)
            .padding(.bottom, BifazSpacing.s)
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

/// The history list of one Summary row: same filter type and query as the Expenses tab.
private struct SummaryHistoryView: View {
    let route: SummaryHistoryRoute
    @Environment(\.modelContext) private var context

    private var title: String {
        let name = route.categoryID
            .flatMap { id in try? context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.id == id })).first }
            .map(\.displayName) ?? String(localized: "summary.noCategory")
        let month = route.month.start.formatted(Date.FormatStyle(capitalizationContext: .middleOfSentence).month(.wide))
        return "\(name) · \(month)"
    }

    var body: some View {
        ExpenseListView(filter: route.filter, onClearFilters: {})
            .navigationTitle(Text(verbatim: title))
            .navigationBarTitleDisplayMode(.inline)
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
