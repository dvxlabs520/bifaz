import Foundation
import SwiftData

// Figures of the Summary tab (phase 3): one month and one space at a time.
//
// One source for every total: the Summary, the history and the budgets read the
// same `ExpenseFilter` predicate and add up `amountInEUR` with `ExpenseTotals`.
// The Summary fetches one six-month window (the evolution chart; it also holds
// the previous month and the quarter so far) and splits it in memory with the
// same month intervals the history uses. All maths is `Decimal`, in EUR.

/// What the Summary needs from one expense, as a value (testable, cheap to pass around).
public struct ExpenseFigure: Sendable, Equatable {
    public var date: Date
    public var space: Space
    /// Amount in EUR, VAT included.
    public var amount: Decimal
    public var categoryID: UUID?
    /// VAT lines (Pro expenses; empty without VAT).
    public var vatLines: [VATPart]

    public init(date: Date, space: Space, amount: Decimal, categoryID: UUID? = nil, vatLines: [VATPart] = []) {
        self.date = date
        self.space = space
        self.amount = amount
        self.categoryID = categoryID
        self.vatLines = vatLines
    }

    /// `includingVAT: false` skips the VAT lines (a to-many fault per expense) when
    /// they are not needed, e.g. outside the quarter shown.
    public init(_ expense: Expense, includingVAT: Bool = true) {
        self.init(
            date: expense.date,
            space: expense.space,
            amount: expense.amountInEUR,
            categoryID: expense.category?.id,
            vatLines: includingVAT && expense.space == .pro ? Self.linesInEUR(expense) : []
        )
    }

    /// VAT lines are in the expense's currency; the Summary adds euros.
    static func linesInEUR(_ expense: Expense) -> [VATPart] {
        let lines = (expense.vatLines ?? []).map(VATPart.init)
        guard expense.isForeignCurrency, let rate = expense.exchangeRate else { return lines }
        return lines.map { line in
            let vat = CurrencyConverter.euros(for: line.vat, rate: rate)
            let total = CurrencyConverter.euros(for: line.total, rate: rate)
            return VATPart(rate: line.rate, base: total - vat, vat: vat, total: total)
        }
    }
}

/// The change against the previous month (same space).
public struct MonthComparison: Sendable, Equatable {
    /// Total of the whole previous month.
    public var previousTotal: Decimal
    /// This month minus the previous one (negative when spending went down).
    public var difference: Decimal
    /// `difference / previousTotal`, e.g. 0.125 for +12,5 %.
    public var fraction: Decimal
    /// The month shown is the current one, still running: it is compared with a full month.
    public var isMonthInProgress: Bool
}

/// One category's share of the month. `categoryID == nil` is "No category".
public struct CategoryShare: Sendable, Equatable, Identifiable {
    public var categoryID: UUID?
    public var amount: Decimal
    /// Share of the month's total, 0…1.
    public var fraction: Decimal
    public var count: Int

    public var id: String { categoryID?.uuidString ?? "none" }
}

/// One bar of the evolution chart.
public struct MonthBar: Sendable, Equatable, Identifiable {
    /// First instant of the month.
    public var month: Date
    public var pro: Decimal
    public var personal: Decimal

    public var total: Decimal { pro + personal }
    public var id: Date { month }
}

/// VAT paid at one rate. `rate == nil`: lines migrated from v1 without a split.
public struct VATRateTotal: Sendable, Equatable, Identifiable {
    public var rate: Decimal?
    public var base: Decimal
    public var vat: Decimal
    public var total: Decimal

    public var id: String { rate.map { "\($0)" } ?? "none" }
}

/// VAT paid on Pro expenses (TVA déductible), for the month and the quarter so far.
public struct VATSummary: Sendable, Equatable {
    public var month: [VATRateTotal]
    /// From the first day of the calendar quarter to the end of the month shown.
    public var quarter: [VATRateTotal]
    public var quarterInterval: DateInterval

    public var monthVAT: Decimal { month.reduce(0) { $0 + $1.vat } }
    public var quarterVAT: Decimal { quarter.reduce(0) { $0 + $1.vat } }
    public var isEmpty: Bool { month.isEmpty && quarter.isEmpty }
}

public struct MonthSummary: Sendable, Equatable {
    public var month: DateInterval
    public var space: SpaceFilter
    public var totals: ExpenseTotals
    /// `nil` when the previous month has no expenses in this space.
    public var comparison: MonthComparison?
    /// Largest first; "No category" is one more row.
    public var categories: [CategoryShare]
    /// Six months, oldest first, ending with `month`.
    public var evolution: [MonthBar]
    /// Pro VAT by rate; `nil` when the space filter leaves Pro out.
    public var vat: VATSummary?
    public var isCurrentMonth: Bool
    /// Spending so far, day by day (see `SummaryCalculator.cumulativeTrend`).
    public var trend: [Decimal] = []
}

public enum SummaryCalculator {
    /// How many months the evolution chart shows.
    public static let evolutionLength = 6

    /// The interval to fetch for `month`: the six months of the chart (it holds the
    /// previous month and the quarter so far too).
    public static func window(for month: DateInterval, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(byAdding: .month, value: -(evolutionLength - 1), to: month.start) ?? month.start
        return DateInterval(start: start, end: month.end)
    }

    /// The calendar quarter of `month`, from its first day to the end of `month`.
    public static func quarterToDate(of month: DateInterval, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.dateInterval(of: .quarter, for: month.start)?.start ?? month.start
        return DateInterval(start: start, end: month.end)
    }

    /// Everything the Summary shows for `month` and `space`, from the expenses of `window(for:)`.
    public static func summary(
        of figures: [ExpenseFigure],
        month: DateInterval,
        space: SpaceFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MonthSummary {
        let inSpace = figures.filter { space.includes($0.space) }
        let thisMonth = inSpace.filter { month.containsHalfOpen($0.date) }
        let totals = ExpenseTotals(figures: thisMonth)

        let previousMonth = ExpenseGrouping.monthInterval(
            containing: calendar.date(byAdding: .month, value: -1, to: month.start) ?? month.start, calendar: calendar
        )
        let previous = inSpace.filter { previousMonth.containsHalfOpen($0.date) }
        let isCurrent = month.containsHalfOpen(now)
        var comparison: MonthComparison?
        if !previous.isEmpty {
            let previousTotal = ExpenseTotals(figures: previous).total
            if previousTotal > 0 {
                let difference = totals.total - previousTotal
                comparison = MonthComparison(
                    previousTotal: previousTotal, difference: difference,
                    fraction: difference / previousTotal, isMonthInProgress: isCurrent
                )
            }
        }

        var vat: VATSummary?
        if space.includes(.pro) {
            let quarter = quarterToDate(of: month, calendar: calendar)
            let pro = figures.filter { $0.space == .pro }
            vat = VATSummary(
                month: byRate(pro.filter { month.containsHalfOpen($0.date) }),
                quarter: byRate(pro.filter { quarter.containsHalfOpen($0.date) }),
                quarterInterval: quarter
            )
        }

        return MonthSummary(
            month: month,
            space: space,
            totals: totals,
            comparison: comparison,
            categories: categories(of: thisMonth, total: totals.total),
            evolution: evolution(of: inSpace, endingWith: month, calendar: calendar),
            vat: vat,
            isCurrentMonth: isCurrent,
            trend: cumulativeTrend(of: figures, month: month, space: space, now: now, calendar: calendar)
        )
    }

    /// The month's spending so far, day by day: point `i` is the total from the
    /// first day to the end of day `i + 1`. Up to today for the current month, the
    /// whole month for a past one (v2 trend line next to the hero amount).
    public static func cumulativeTrend(
        of figures: [ExpenseFigure],
        month: DateInterval,
        space: SpaceFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Decimal] {
        let dayCount = calendar.range(of: .day, in: .month, for: month.start)?.count ?? 0
        let lastDay: Int
        if month.containsHalfOpen(now) {
            lastDay = calendar.component(.day, from: now)
        } else if now < month.start {
            return []
        } else {
            lastDay = dayCount
        }
        var perDay = [Decimal](repeating: 0, count: max(lastDay, 0))
        for figure in figures where space.includes(figure.space) && month.containsHalfOpen(figure.date) {
            let day = calendar.component(.day, from: figure.date)
            if day >= 1, day <= lastDay { perDay[day - 1] += figure.amount }
        }
        var running: Decimal = 0
        return perDay.map { amount in
            running += amount
            return running
        }
    }

    static func categories(of figures: [ExpenseFigure], total: Decimal) -> [CategoryShare] {
        var shares: [UUID?: CategoryShare] = [:]
        for figure in figures {
            shares[figure.categoryID, default: CategoryShare(categoryID: figure.categoryID, amount: 0, fraction: 0, count: 0)]
                .amount += figure.amount
            shares[figure.categoryID]?.count += 1
        }
        return shares.values
            .map { share in
                var share = share
                share.fraction = total > 0 ? share.amount / total : 0
                return share
            }
            .sorted { lhs, rhs in
                // Largest first; ties by count, then "No category" last, then a stable id.
                if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if (lhs.categoryID == nil) != (rhs.categoryID == nil) { return rhs.categoryID == nil }
                return lhs.id < rhs.id
            }
    }

    static func evolution(of figures: [ExpenseFigure], endingWith month: DateInterval, calendar: Calendar) -> [MonthBar] {
        let months: [DateInterval] = (0..<evolutionLength).reversed().map { back in
            let date = calendar.date(byAdding: .month, value: -back, to: month.start) ?? month.start
            return ExpenseGrouping.monthInterval(containing: date, calendar: calendar)
        }
        var bars = months.map { MonthBar(month: $0.start, pro: 0, personal: 0) }
        for figure in figures {
            guard let index = months.firstIndex(where: { $0.containsHalfOpen(figure.date) }) else { continue }
            switch figure.space {
            case .pro: bars[index].pro += figure.amount
            case .personal: bars[index].personal += figure.amount
            }
        }
        return bars
    }

    /// VAT lines added up by rate, highest rate first ("not detailed" last).
    static func byRate(_ figures: [ExpenseFigure]) -> [VATRateTotal] {
        var totals: [Decimal?: VATRateTotal] = [:]
        for line in figures.lazy.flatMap(\.vatLines) {
            totals[line.rate, default: VATRateTotal(rate: line.rate, base: 0, vat: 0, total: 0)].base += line.base
            totals[line.rate]?.vat += line.vat
            totals[line.rate]?.total += line.total
        }
        return totals.values.sorted { ($0.rate ?? -1) > ($1.rate ?? -1) }
    }
}

extension DateInterval {
    /// Start included, end excluded (months are back to back).
    public func containsHalfOpen(_ date: Date) -> Bool { date >= start && date < end }
}

// MARK: - Loading from the store

/// Reads the Summary from a context with the history's own predicate.
public enum SummaryService {
    /// The figures of `window(for: month)`, all spaces (the chart stacks Pro and Personal).
    /// VAT lines are read only where the Summary shows VAT: Pro, in the quarter so far.
    public static func figures(around month: DateInterval, in context: ModelContext, calendar: Calendar = .current) throws -> [ExpenseFigure] {
        var descriptor = ExpenseFilter(dateInterval: SummaryCalculator.window(for: month, calendar: calendar)).fetchDescriptor
        descriptor.sortBy = []
        descriptor.relationshipKeyPathsForPrefetching = [\.category]
        let quarter = SummaryCalculator.quarterToDate(of: month, calendar: calendar)
        return try context.fetch(descriptor).map { expense in
            ExpenseFigure(expense, includingVAT: quarter.containsHalfOpen(expense.date))
        }
    }

    public static func summary(
        for month: DateInterval,
        space: SpaceFilter,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> MonthSummary {
        let figures = try figures(around: month, in: context, calendar: calendar)
        return SummaryCalculator.summary(of: figures, month: month, space: space, now: now, calendar: calendar)
    }

    /// The month of the oldest expense, if any (how far back the Summary can go).
    public static func firstMonth(in context: ModelContext, calendar: Calendar = .current) throws -> DateInterval? {
        var descriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { ExpenseGrouping.monthInterval(containing: $0.date, calendar: calendar) }
    }
}

// MARK: - Off the main thread

/// What the Summary tab shows for one month and space.
public struct SummaryResult: Sendable, Equatable {
    public var summary: MonthSummary
    public var budgets: [BudgetStatus]
    /// How far back the month picker goes (`nil`: no expenses yet).
    public var firstMonth: DateInterval?
}

/// Computes the Summary on its own context, off the main thread, so changing
/// month never blocks the interface. Keeps each month's figures until the store
/// changes (`version`), so moving to the next or previous month reads one month,
/// not six (5,000 expenses: see SummaryPerformanceTests).
@ModelActor
public actor SummaryLoader {
    private var cache: [Date: [ExpenseFigure]] = [:]
    private var cacheVersion: Int?

    public func load(
        month: DateInterval,
        space: SpaceFilter,
        version: Int = 0,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> SummaryResult {
        if version != cacheVersion {
            cache = [:]
            cacheVersion = version
        }
        let figures = try figures(around: month, calendar: calendar)
        let summary = SummaryCalculator.summary(of: figures, month: month, space: space, now: now, calendar: calendar)
        var budgetDescriptor = FetchDescriptor<Budget>()
        budgetDescriptor.relationshipKeyPathsForPrefetching = [\.category]
        let budgets = BudgetService.statuses(
            try modelContext.fetch(budgetDescriptor), figures: figures, month: month, space: space, now: now, calendar: calendar
        )
        return SummaryResult(
            summary: summary, budgets: budgets,
            firstMonth: try SummaryService.firstMonth(in: modelContext, calendar: calendar)
        )
    }

    /// The window's figures, reading only the months not in the cache (in one fetch).
    private func figures(around month: DateInterval, calendar: Calendar) throws -> [ExpenseFigure] {
        let window = SummaryCalculator.window(for: month, calendar: calendar)
        let months = (0..<SummaryCalculator.evolutionLength).map { offset in
            ExpenseGrouping.monthInterval(
                containing: calendar.date(byAdding: .month, value: offset, to: window.start) ?? window.start, calendar: calendar
            )
        }
        let missing = months.filter { cache[$0.start] == nil }
        if let first = missing.first, let last = missing.last {
            var descriptor = ExpenseFilter(dateInterval: DateInterval(start: first.start, end: last.end)).fetchDescriptor
            descriptor.sortBy = []
            descriptor.relationshipKeyPathsForPrefetching = [\.category, \.vatLines]
            var fetched: [Date: [ExpenseFigure]] = Dictionary(uniqueKeysWithValues: missing.map { ($0.start, []) })
            for expense in try modelContext.fetch(descriptor) {
                guard let key = missing.first(where: { $0.containsHalfOpen(expense.date) })?.start else { continue }
                fetched[key]?.append(ExpenseFigure(expense))
            }
            cache.merge(fetched) { _, new in new }
        }
        return months.flatMap { cache[$0.start] ?? [] }
    }
}
