import Foundation
import SwiftData
import Testing
@testable import BifazModels

@Suite("Monogram")
struct MonogramTests {
    @Test("Initial of a merchant", arguments: [
        ("Carrefour", "C"), ("carrefour city", "C"), ("éclair & co", "É"), ("Œuvre", "Œ"),
        ("« Le Zinc »", "L"), ("  Monoprix", "M"), ("7-Eleven", "7"), ("2 Frères", "2"),
        ("x", "X"), ("", "·"), ("   ", "·"), ("—", "·"), ("e\u{301}picerie", "E\u{301}"),
    ])
    func initial(name: String, expected: String) {
        #expect(Monogram.initial(for: name, locale: Locale(identifier: "fr_FR")) == expected)
    }

    @Test("Turkish dotted i follows the locale")
    func locale() {
        #expect(Monogram.initial(for: "istanbul kebab", locale: Locale(identifier: "tr_TR")) == "İ")
    }
}

@MainActor
@Suite("Days and trend")
struct DaysAndTrendTests {
    static let cal = parisCalendar

    @Test("Expenses grouped by Paris day, newest first; days add up to the month")
    func byDay() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        // 23:59 and 00:01 Paris are different days, even if UTC says otherwise.
        let dates = [parisDate(2026, 11, 2, hour: 23, minute: 59), parisDate(2026, 11, 3, hour: 0, minute: 1),
                     parisDate(2026, 11, 3, hour: 9), parisDate(2026, 11, 30, hour: 23, minute: 59), parisDate(2026, 11, 1, hour: 0)]
        for (index, date) in dates.enumerated() {
            try ExpenseService.create(from: ExpenseDraft(amount: Decimal(index + 1) + Decimal(string: "0.25")!, date: date), in: context)
        }
        let expenses = try ExpenseFilter().fetch(in: context)
        let days = ExpenseGrouping.byDay(expenses, calendar: Self.cal)
        let keys = days.map { Self.cal.component(.day, from: $0.day) }
        #expect(keys == [30, 3, 2, 1])
        #expect(days[1].expenses.count == 2)
        #expect(days[1].expenses.first?.date == dates[2]) // newest first within the day
        let month = ExpenseGrouping.monthInterval(containing: parisDate(2026, 11, 15), calendar: Self.cal)
        let monthTotal = ExpenseTotals(try ExpenseFilter(dateInterval: month).fetch(in: context)).total
        #expect(days.reduce(Decimal(0)) { $0 + $1.totals.total } == monthTotal)
        #expect(monthTotal == decimal("16.25"))
    }

    @Test("Generated data: the days of every month add up to the month", arguments: [UInt64(3), 11])
    func generated(seed: UInt64) throws {
        let (container, _) = try SummaryTests.generatedStore(seed: seed, count: 400)
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        for monthNumber in [1, 6, 11] {
            let month = ExpenseGrouping.monthInterval(containing: parisDate(2026, monthNumber, 15), calendar: Self.cal)
            let expenses = try ExpenseFilter(dateInterval: month).fetch(in: context)
            let days = ExpenseGrouping.byDay(expenses, calendar: Self.cal)
            #expect(days.reduce(Decimal(0)) { $0 + $1.totals.total } == ExpenseTotals(expenses).total)
            #expect(days.allSatisfy { day in day.expenses.allSatisfy { Self.cal.isDate($0.date, inSameDayAs: day.day) } })
        }
    }

    static func figure(_ amount: String, _ day: Int, hour: Int = 12, space: Space = .pro) -> ExpenseFigure {
        ExpenseFigure(date: parisDate(2026, 11, day, hour: hour), space: space, amount: decimal(amount))
    }

    @Test("Trend: running total per day, up to today in the current month")
    func trendCurrent() {
        let month = ExpenseGrouping.monthInterval(containing: parisDate(2026, 11, 15), calendar: Self.cal)
        let figures = [Self.figure("10", 1), Self.figure("5", 3, hour: 23), Self.figure("2.50", 3), Self.figure("99", 20),
                       Self.figure("1", 2, space: .personal)]
        let trend = SummaryCalculator.cumulativeTrend(of: figures, month: month, space: .pro,
                                                      now: parisDate(2026, 11, 4, hour: 8), calendar: Self.cal)
        #expect(trend == [10, 10, decimal("17.5"), decimal("17.5")])
        let all = SummaryCalculator.cumulativeTrend(of: figures, month: month, space: .all,
                                                    now: parisDate(2026, 11, 4, hour: 8), calendar: Self.cal)
        #expect(all == [10, 11, decimal("18.5"), decimal("18.5")])
    }

    @Test("Trend: a past month runs to its last day and ends at the month total")
    func trendPast() {
        let month = ExpenseGrouping.monthInterval(containing: parisDate(2026, 2, 15), calendar: Self.cal)
        let figures = [ExpenseFigure(date: parisDate(2026, 2, 28, hour: 23, minute: 59), space: .pro, amount: 7),
                       ExpenseFigure(date: parisDate(2026, 3, 1, hour: 0), space: .pro, amount: 100)]
        let trend = SummaryCalculator.cumulativeTrend(of: figures, month: month, space: .all,
                                                      now: parisDate(2026, 11, 17), calendar: Self.cal)
        #expect(trend.count == 28)
        #expect(trend.last == 7)
        #expect(trend.dropLast().allSatisfy { $0 == 0 })
        let future = ExpenseGrouping.monthInterval(containing: parisDate(2027, 1, 15), calendar: Self.cal)
        #expect(SummaryCalculator.cumulativeTrend(of: figures, month: future, space: .all,
                                                  now: parisDate(2026, 11, 17), calendar: Self.cal).isEmpty)
    }

    @Test("The summary carries the trend, ending at its total")
    func summaryTrend() {
        let month = ExpenseGrouping.monthInterval(containing: parisDate(2026, 11, 15), calendar: Self.cal)
        let figures = [Self.figure("10", 1), Self.figure("5", 3)]
        let summary = SummaryCalculator.summary(of: figures, month: month, space: .all,
                                                now: parisDate(2026, 11, 17), calendar: Self.cal)
        #expect(summary.trend.count == 17)
        #expect(summary.trend.last == summary.totals.total)
    }
}

@MainActor
@Suite("Recent merchants")
struct RecentMerchantsTests {
    @Test("Most recent first, one per merchant, limited")
    func recent() async throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        for name in ["Carrefour", "Monoprix", "SNCF", "carrefour", "Fnac"] {
            try ExpenseService.create(from: ExpenseDraft(amount: 1, merchant: name), in: context)
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(MerchantMemory.recentMerchants(limit: 3, in: context) == ["Fnac", "carrefour", "SNCF"])
        #expect(MerchantMemory.recentMerchants(in: context).count == 4)
    }
}
