import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("ExpenseQuery")
struct ExpenseQueryTests {
    /// Fixture: categories plus expenses spread over three months.
    @MainActor struct Fixture {
        let container: ModelContainer
        var context: ModelContext { container.mainContext }
        let meals: ExpenseCategory
        let groceries: ExpenseCategory
        let jan: Expense, feb1: Expense, feb2: Expense, mar: Expense

        init() throws {
            container = try makeTestContainer()
            let context = container.mainContext
            meals = ExpenseCategory(name: "Repas", space: .pro)
            groceries = ExpenseCategory(name: "Épicerie", space: .personal)
            context.insert(meals); context.insert(groceries)
            jan = Expense(amount: 10, date: parisDate(2026, 1, 15), merchant: "Café Flore", space: .pro,
                          category: meals, vatRate: decimal("0.10"), vatAmount: decimal("0.91"), note: "déjeuner client")
            feb1 = Expense(amount: 20, date: parisDate(2026, 2, 1, hour: 0), merchant: "Monoprix", space: .personal,
                           category: groceries, note: "courses")
            feb2 = Expense(amount: 30, date: parisDate(2026, 2, 20), merchant: "Uber", space: .pro,
                           vatRate: decimal("0.20"), vatAmount: 5, status: .receiptPending)
            mar = Expense(amount: 5.5, date: parisDate(2026, 3, 3), merchant: "Fnac", space: .personal, category: groceries)
            for (offset, e) in [jan, feb1, feb2, mar].enumerated() {
                e.createdAt = Date(timeIntervalSince1970: Double(offset))
                context.insert(e)
            }
            try context.save()
        }
    }

    private func merchants(_ expenses: [Expense]) -> [String] { expenses.map(\.merchant) }

    @Test("Default filter returns everything, newest first")
    func sortNewestFirst() throws {
        let f = try Fixture()
        #expect(merchants(try ExpenseFilter().fetch(in: f.context)) == ["Fnac", "Uber", "Monoprix", "Café Flore"])
    }

    @Test("Same date sorts by createdAt, newest first")
    func sameDateTieBreak() throws {
        let f = try Fixture()
        let day = parisDate(2026, 4, 1)
        let older = Expense(amount: 1, date: day, merchant: "Older", space: .pro)
        let newer = Expense(amount: 1, date: day, merchant: "Newer", space: .pro)
        older.createdAt = Date(timeIntervalSince1970: 100)
        newer.createdAt = Date(timeIntervalSince1970: 200)
        f.context.insert(older); f.context.insert(newer)
        #expect(merchants(try ExpenseFilter().fetch(in: f.context)).prefix(2) == ["Newer", "Older"])
    }

    @Test("Space filter", arguments: [
        (SpaceFilter.pro, ["Uber", "Café Flore"]),
        (.personal, ["Fnac", "Monoprix"]),
        (.all, ["Fnac", "Uber", "Monoprix", "Café Flore"]),
    ])
    func space(filter: SpaceFilter, expected: [String]) throws {
        let f = try Fixture()
        #expect(merchants(try ExpenseFilter(space: filter).fetch(in: f.context)) == expected)
    }

    @Test("Date interval: start inclusive, end exclusive")
    func dateInterval() throws {
        let f = try Fixture()
        let february = DateInterval(start: parisDate(2026, 2, 1, hour: 0), end: parisDate(2026, 3, 1, hour: 0))
        #expect(merchants(try ExpenseFilter(dateInterval: february).fetch(in: f.context)) == ["Uber", "Monoprix"])
        // End exactly at the first February expense: it is excluded.
        let toJan = DateInterval(start: parisDate(2026, 1, 1, hour: 0), end: parisDate(2026, 2, 1, hour: 0))
        #expect(merchants(try ExpenseFilter(dateInterval: toJan).fetch(in: f.context)) == ["Café Flore"])
    }

    @Test("Category filter")
    func categories() throws {
        let f = try Fixture()
        #expect(merchants(try ExpenseFilter(categoryIDs: [f.meals.id]).fetch(in: f.context)) == ["Café Flore"])
        #expect(merchants(try ExpenseFilter(categoryIDs: [f.meals.id, f.groceries.id]).fetch(in: f.context)) == ["Fnac", "Monoprix", "Café Flore"])
        #expect(try ExpenseFilter(categoryIDs: [UUID()]).fetch(in: f.context).isEmpty)
    }

    @Test("Only receipt pending")
    func receiptPending() throws {
        let f = try Fixture()
        #expect(merchants(try ExpenseFilter(onlyReceiptPending: true).fetch(in: f.context)) == ["Uber"])
    }

    @Test("Search is accent and case insensitive across merchant, note and category", arguments: [
        ("cafe", ["Café Flore"]),
        ("CAFÉ", ["Café Flore"]),
        ("dejeuner", ["Café Flore"]),
        ("COURSES", ["Monoprix"]),
        ("epicerie", ["Fnac", "Monoprix"]),
        ("repas", ["Café Flore"]),
        ("uber", ["Uber"]),
        ("zzz", []),
        ("   ", ["Fnac", "Uber", "Monoprix", "Café Flore"]),
    ])
    func search(text: String, expected: [String]) throws {
        let f = try Fixture()
        #expect(merchants(try ExpenseFilter(searchText: text).fetch(in: f.context)) == expected)
    }

    @Test("Multi-word search is an AND across fields")
    func multiWordSearch() throws {
        let f = try Fixture()
        #expect(merchants(try ExpenseFilter(searchText: "cafe client").fetch(in: f.context)) == ["Café Flore"])
        #expect(merchants(try ExpenseFilter(searchText: "monoprix epicerie").fetch(in: f.context)) == ["Monoprix"])
        #expect(try ExpenseFilter(searchText: "cafe monoprix").fetch(in: f.context).isEmpty)
    }

    @Test("Filters combine")
    func combined() throws {
        let f = try Fixture()
        let filter = ExpenseFilter(space: .personal, dateInterval: DateInterval(start: parisDate(2026, 3, 1, hour: 0), end: parisDate(2026, 4, 1, hour: 0)), searchText: "fnac")
        #expect(merchants(try filter.fetch(in: f.context)) == ["Fnac"])
    }

    @Test("activeRefinementCount ignores space and search")
    func refinementCount() {
        #expect(ExpenseFilter().activeRefinementCount == 0)
        #expect(ExpenseFilter(space: .pro, searchText: "x").activeRefinementCount == 0)
        #expect(ExpenseFilter(categoryIDs: [UUID()]).activeRefinementCount == 1)
        #expect(ExpenseFilter(dateInterval: DateInterval(start: .now, duration: 1)).activeRefinementCount == 1)
        #expect(ExpenseFilter(onlyReceiptPending: true).activeRefinementCount == 1)
        #expect(ExpenseFilter(categoryIDs: [UUID()], dateInterval: DateInterval(start: .now, duration: 1), onlyReceiptPending: true).activeRefinementCount == 3)
    }

    @Test("Totals")
    func totals() throws {
        let f = try Fixture()
        let totals = ExpenseTotals([f.jan, f.feb1, f.feb2, f.mar])
        #expect(totals.total == decimal("65.5"))
        #expect(totals.pro == 40)
        #expect(totals.personal == decimal("25.5"))
        #expect(totals.proVAT == decimal("5.91"))
        #expect(totals.count == 4)
        #expect(ExpenseTotals([Expense]()) == ExpenseTotals())
        #expect(ExpenseTotals().count == 0)
    }

    @Test("Totals ignore VAT on personal expenses")
    func personalVATIgnored() throws {
        let f = try Fixture()
        let e = Expense(amount: 10, space: .personal, vatRate: decimal("0.20"), vatAmount: 99)
        f.context.insert(e)
        #expect(ExpenseTotals([e]).proVAT == 0)
    }

    @Test("byMonth orders months newest first with per-month totals")
    func byMonth() throws {
        let f = try Fixture()
        // Deliberately shuffled input.
        let groups = ExpenseGrouping.byMonth([f.feb1, f.mar, f.jan, f.feb2], calendar: parisCalendar)
        #expect(groups.map(\.month) == [parisDate(2026, 3, 1, hour: 0), parisDate(2026, 2, 1, hour: 0), parisDate(2026, 1, 1, hour: 0)])
        #expect(groups.map(\.id) == groups.map(\.month))
        #expect(merchants(groups[1].expenses) == ["Monoprix", "Uber"]) // incoming order kept
        #expect(groups.map(\.totals.count) == [1, 2, 1])
        #expect(groups.map(\.totals.total) == [decimal("5.5"), 50, 10])
        #expect(groups[1].totals.pro == 30)
        #expect(groups[1].totals.personal == 20)
        #expect(groups[1].totals.proVAT == 5)
    }

    @Test("byMonth of nothing is empty")
    func byMonthEmpty() {
        #expect(ExpenseGrouping.byMonth([], calendar: parisCalendar).isEmpty)
    }

    @Test("byMonth uses the calendar's time zone at month boundaries")
    func byMonthBoundary() throws {
        let f = try Fixture()
        // 00:30 on 1 March in Paris is still 28 February in UTC.
        let edge = Expense(amount: 1, date: parisDate(2026, 3, 1, hour: 0, minute: 30), merchant: "Edge", space: .pro)
        f.context.insert(edge)
        let groups = ExpenseGrouping.byMonth([edge], calendar: parisCalendar)
        #expect(groups.map(\.month) == [parisDate(2026, 3, 1, hour: 0)])
    }

    @Test("monthInterval(containing:) spans the whole month")
    func monthInterval() {
        let interval = ExpenseGrouping.monthInterval(containing: parisDate(2026, 2, 14), calendar: parisCalendar)
        #expect(interval.start == parisDate(2026, 2, 1, hour: 0))
        #expect(interval.end == parisDate(2026, 3, 1, hour: 0))
        // Leap-year February and a month across the DST change.
        let leap = ExpenseGrouping.monthInterval(containing: parisDate(2028, 2, 10), calendar: parisCalendar)
        #expect(leap.end == parisDate(2028, 3, 1, hour: 0))
        let dst = ExpenseGrouping.monthInterval(containing: parisDate(2026, 3, 29), calendar: parisCalendar)
        #expect(dst.start == parisDate(2026, 3, 1, hour: 0))
        #expect(dst.end == parisDate(2026, 4, 1, hour: 0))
    }

    @Test("A month interval used as a filter includes the first instant and excludes the next month")
    func monthIntervalAsFilter() throws {
        let f = try Fixture()
        let interval = ExpenseGrouping.monthInterval(containing: parisDate(2026, 2, 14), calendar: parisCalendar)
        #expect(merchants(try ExpenseFilter(dateInterval: interval).fetch(in: f.context)) == ["Uber", "Monoprix"])
    }
}
