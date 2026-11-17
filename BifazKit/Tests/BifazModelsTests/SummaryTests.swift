import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("Summary")
struct SummaryTests {
    static func month(_ year: Int, _ month: Int) -> DateInterval {
        ExpenseGrouping.monthInterval(containing: parisDate(year, month, 15), calendar: parisCalendar)
    }

    // MARK: Generated data: the Summary equals the history to the cent

    /// A seeded store: 14 months of expenses in both spaces, some without category,
    /// some with one or two VAT rates, many on the first and last instant of a month.
    static func generatedStore(seed: UInt64, count: Int) throws -> (ModelContainer, [ExpenseCategory]) {
        let container = try makeTestContainer()
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<count {
            let year = Bool.random(using: &rng) ? 2025 : 2026
            let monthNumber = Int.random(in: 1...12, using: &rng)
            let interval = ExpenseGrouping.monthInterval(containing: parisDate(year, monthNumber, 10), calendar: parisCalendar)
            let date: Date = switch Int.random(in: 0...4, using: &rng) {
            case 0: interval.start
            case 1: interval.end.addingTimeInterval(-1)
            default: interval.start.addingTimeInterval(Double.random(in: 0..<interval.duration, using: &rng))
            }
            let space: Space = Bool.random(using: &rng) ? .pro : .personal
            let inSpace = categories.filter { $0.space == space }
            let category = Int.random(in: 0...4, using: &rng) == 0 ? nil : inSpace.randomElement(using: &rng)
            var draft = ExpenseDraft(
                amount: Decimal(Int.random(in: 1...250_000, using: &rng)) / 100,
                date: date, space: space, category: category
            )
            if space == .pro, Int.random(in: 0...3, using: &rng) > 0 {
                draft.vatRate = VATRate.allCases.randomElement(using: &rng)
                if Bool.random(using: &rng), let amount = draft.amount, amount > 1 {
                    let part = (amount * Decimal(Int.random(in: 1...99, using: &rng)) / 100).rounded(scale: 2)
                    if part > 0, part < amount { draft.secondVAT = .init(rate: VATRate.allCases.randomElement(using: &rng)!, total: part) }
                }
            }
            try ExpenseService.create(from: draft, in: context)
        }
        return (container, categories)
    }

    @Test("Summary totals equal the history for every month and space", arguments: [UInt64(7), 42, 2026])
    func matchesHistory(seed: UInt64) throws {
        let (container, categories) = try Self.generatedStore(seed: seed, count: 700)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let history = { (filter: ExpenseFilter) in try ExpenseTotals(filter.fetch(in: context)) }

        for (year, monthNumber) in [(2025, 1), (2025, 6), (2025, 12), (2026, 1), (2026, 3), (2026, 12)] {
            let month = Self.month(year, monthNumber)
            for space in SpaceFilter.allCases {
                let summary = try SummaryService.summary(
                    for: month, space: space, in: context, now: parisDate(2027, 1, 1), calendar: parisCalendar
                )
                let historyMonth = try history(ExpenseFilter(space: space, dateInterval: month))
                #expect(summary.totals == historyMonth, "\(year)-\(monthNumber) \(space)")

                // Categories add up to the total, and each one equals the filtered history.
                #expect(summary.categories.reduce(0) { $0 + $1.amount } == summary.totals.total)
                for share in summary.categories {
                    let filter = share.categoryID.map { ExpenseFilter(space: space, categoryIDs: [$0], dateInterval: month) }
                        ?? ExpenseFilter(space: space, withoutCategory: true, dateInterval: month)
                    #expect(try history(filter).total == share.amount)
                    #expect(try history(filter).count == share.count)
                }
                #expect(Set(summary.categories.compactMap(\.categoryID)).isSubset(of: Set(categories.map(\.id))))

                // Each bar of the chart equals that month of the history.
                for bar in summary.evolution {
                    let barMonth = ExpenseGrouping.monthInterval(containing: bar.month, calendar: parisCalendar)
                    let totals = try history(ExpenseFilter(space: space, dateInterval: barMonth))
                    #expect(bar.pro == totals.pro && bar.personal == totals.personal)
                }

                // VAT: month and quarter so far equal the history's Pro VAT.
                if let vat = summary.vat {
                    #expect(vat.monthVAT == historyMonth.proVAT)
                    let quarter = try history(ExpenseFilter(space: .pro, dateInterval: vat.quarterInterval))
                    #expect(vat.quarterVAT == quarter.proVAT)
                    #expect(vat.quarter.reduce(0) { $0 + $1.total } <= quarter.pro)
                } else {
                    #expect(space == .personal)
                }
            }
        }
    }

    @Test("Each history month header equals the Summary of that month")
    func historyHeaders() throws {
        let (container, _) = try Self.generatedStore(seed: 99, count: 300)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let groups = ExpenseGrouping.byMonth(try ExpenseFilter().fetch(in: context), calendar: parisCalendar)
        #expect(!groups.isEmpty)
        for group in groups {
            let month = ExpenseGrouping.monthInterval(containing: group.month, calendar: parisCalendar)
            let summary = try SummaryService.summary(for: month, space: .all, in: context, calendar: parisCalendar)
            #expect(summary.totals == group.totals)
        }
    }

    @Test("The background loader, with its month cache, gives the same Summary")
    func loaderMatches() async throws {
        let (container, _) = try Self.generatedStore(seed: 5, count: 400)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let loader = SummaryLoader(modelContainer: container)
        let now = parisDate(2026, 11, 17)
        for (year, monthNumber) in [(2026, 11), (2026, 10), (2026, 9), (2026, 3), (2026, 4), (2025, 12)] {
            let month = Self.month(year, monthNumber)
            for space in SpaceFilter.allCases {
                let loaded = try await loader.load(month: month, space: space, now: now, calendar: parisCalendar)
                let direct = try SummaryService.summary(for: month, space: space, in: context, now: now, calendar: parisCalendar)
                #expect(loaded.summary == direct, "\(year)-\(monthNumber) \(space)")
            }
        }
        // A save the cache has not seen: with a new version the loader reads it.
        let month = Self.month(2026, 11)
        let before = try await loader.load(month: month, space: .all, version: 0, now: now, calendar: parisCalendar)
        try ExpenseService.create(from: ExpenseDraft(amount: 10, date: parisDate(2026, 11, 2)), in: context)
        let stale = try await loader.load(month: month, space: .all, version: 0, now: now, calendar: parisCalendar)
        #expect(stale.summary.totals == before.summary.totals)
        let fresh = try await loader.load(month: month, space: .all, version: 1, now: now, calendar: parisCalendar)
        #expect(fresh.summary.totals.total == before.summary.totals.total + 10)
    }

    // MARK: Comparison

    static func figure(_ amount: String, _ year: Int, _ month: Int, _ day: Int = 10, space: Space = .pro,
                       category: UUID? = nil, vat: [VATPart] = []) -> ExpenseFigure {
        ExpenseFigure(date: parisDate(year, month, day), space: space, amount: decimal(amount), categoryID: category, vatLines: vat)
    }

    @Test("Against the previous month: amount and percentage")
    func comparison() {
        let figures = [Self.figure("100", 2026, 9), Self.figure("80", 2026, 10), Self.figure("32.50", 2026, 10)]
        let summary = SummaryCalculator.summary(of: figures, month: Self.month(2026, 10), space: .all,
                                                now: parisDate(2026, 11, 17), calendar: parisCalendar)
        #expect(summary.comparison == MonthComparison(previousTotal: 100, difference: decimal("12.50"),
                                                      fraction: decimal("0.125"), isMonthInProgress: false))
        let down = SummaryCalculator.summary(of: figures, month: Self.month(2026, 10), space: .pro,
                                             now: parisDate(2026, 10, 20), calendar: parisCalendar)
        #expect(down.comparison?.isMonthInProgress == true)
    }

    @Test("No previous month with expenses in this space: no comparison")
    func noComparison() {
        let figures = [Self.figure("100", 2026, 9, space: .personal), Self.figure("80", 2026, 10)]
        let month = Self.month(2026, 10)
        #expect(SummaryCalculator.summary(of: figures, month: month, space: .pro, calendar: parisCalendar).comparison == nil)
        #expect(SummaryCalculator.summary(of: figures, month: month, space: .all, calendar: parisCalendar).comparison != nil)
        #expect(SummaryCalculator.summary(of: [], month: month, space: .all, calendar: parisCalendar).comparison == nil)
    }

    @Test("A month with nothing against a month with something: −100 %")
    func emptyMonth() {
        let summary = SummaryCalculator.summary(of: [Self.figure("40", 2026, 9)], month: Self.month(2026, 10),
                                                space: .all, calendar: parisCalendar)
        #expect(summary.comparison?.fraction == -1)
        #expect(summary.totals.total == 0)
        #expect(summary.categories.isEmpty)
    }

    // MARK: Categories, evolution, VAT

    @Test("Categories largest first, with No category as one more row")
    func categoryOrder() {
        let a = UUID(), b = UUID()
        let figures = [
            Self.figure("10", 2026, 10, category: a), Self.figure("50", 2026, 10, category: b),
            Self.figure("20", 2026, 10), Self.figure("20", 2026, 10, category: a),
        ]
        let shares = SummaryCalculator.summary(of: figures, month: Self.month(2026, 10), space: .all, calendar: parisCalendar).categories
        #expect(shares.map(\.categoryID) == [b, a, nil])
        #expect(shares.map(\.amount) == [50, 30, 20])
        #expect(shares.map(\.fraction) == [decimal("0.5"), decimal("0.3"), decimal("0.2")])
    }

    @Test("Six bars, oldest first, Pro and Personal apart")
    func evolution() {
        let figures = [
            Self.figure("10", 2026, 5), Self.figure("99", 2026, 4),
            Self.figure("7", 2026, 10, space: .personal), Self.figure("3", 2026, 10),
        ]
        let bars = SummaryCalculator.summary(of: figures, month: Self.month(2026, 10), space: .all, calendar: parisCalendar).evolution
        #expect(bars.count == 6)
        #expect(bars.first?.month == Self.month(2026, 5).start)
        #expect(bars.first?.pro == 10)
        #expect(bars.last.map { [$0.pro, $0.personal] } == [3, 7])
        // The year boundary.
        let january = SummaryCalculator.summary(of: [], month: Self.month(2026, 1), space: .all, calendar: parisCalendar)
        #expect(january.evolution.first?.month == Self.month(2025, 8).start)
    }

    @Test("Quarter so far: from the first day of the quarter to the end of the month")
    func quarter() {
        #expect(SummaryCalculator.quarterToDate(of: Self.month(2026, 2), calendar: parisCalendar)
            == DateInterval(start: Self.month(2026, 1).start, end: Self.month(2026, 2).end))
        #expect(SummaryCalculator.quarterToDate(of: Self.month(2026, 10), calendar: parisCalendar)
            == Self.month(2026, 10))
    }

    @Test("VAT by rate: Pro only, month and quarter so far")
    func vatByRate() throws {
        let twenty = VATPart.computed(total: 120, rate: decimal("0.20"))
        let ten = VATPart.computed(total: 110, rate: decimal("0.10"))
        let figures = [
            Self.figure("120", 2026, 10, vat: [twenty]),
            Self.figure("110", 2026, 8, vat: [ten]),
            Self.figure("230", 2026, 7, vat: [twenty, ten]),
            Self.figure("120", 2026, 6, vat: [twenty]), // previous quarter
            Self.figure("120", 2026, 8, space: .personal),
        ]
        let summary = SummaryCalculator.summary(of: figures, month: Self.month(2026, 8), space: .all, calendar: parisCalendar)
        let vat = try #require(summary.vat)
        #expect(vat.month == [VATRateTotal(rate: decimal("0.10"), base: 100, vat: 10, total: 110)])
        #expect(vat.quarter == [
            VATRateTotal(rate: decimal("0.20"), base: 100, vat: 20, total: 120),
            VATRateTotal(rate: decimal("0.10"), base: 200, vat: 20, total: 220),
        ])
        #expect(vat.quarterVAT == 40)
        #expect(SummaryCalculator.summary(of: figures, month: Self.month(2026, 8), space: .personal, calendar: parisCalendar).vat == nil)
    }

    @Test("The window holds the chart, the previous month and the quarter")
    func window() {
        for monthNumber in 1...12 {
            let month = Self.month(2026, monthNumber)
            let window = SummaryCalculator.window(for: month, calendar: parisCalendar)
            #expect(window.end == month.end)
            #expect(window.start <= SummaryCalculator.quarterToDate(of: month, calendar: parisCalendar).start)
            #expect(window.start == Self.month(monthNumber > 5 ? 2026 : 2025, (monthNumber + 6) % 12 + 1).start)
        }
    }

    @Test("First month of the history")
    func firstMonth() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        #expect(try SummaryService.firstMonth(in: context, calendar: parisCalendar) == nil)
        try ExpenseService.create(from: ExpenseDraft(amount: 1, date: parisDate(2025, 3, 31, hour: 23)), in: context)
        try ExpenseService.create(from: ExpenseDraft(amount: 1, date: parisDate(2026, 3, 1)), in: context)
        #expect(try SummaryService.firstMonth(in: context, calendar: parisCalendar) == Self.month(2025, 3))
    }

    @Test("The no-category filter")
    func withoutCategoryFilter() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)
        let groceries = try #require(try context.fetch(FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.seedKey == "category.personal.groceries" })).first)
        try ExpenseService.create(from: ExpenseDraft(amount: 5, category: groceries), in: context)
        try ExpenseService.create(from: ExpenseDraft(amount: 7), in: context)
        #expect(try ExpenseFilter(withoutCategory: true).fetch(in: context).map(\.amount) == [7])
        #expect(try ExpenseFilter(categoryIDs: [groceries.id], withoutCategory: true).fetch(in: context).count == 2)
        #expect(ExpenseFilter(withoutCategory: true).activeRefinementCount == 1)
    }
}
