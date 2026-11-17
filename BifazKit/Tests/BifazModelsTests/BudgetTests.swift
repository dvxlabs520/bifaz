import Foundation
import SwiftData
import Testing
@testable import BifazModels

@Suite("Budgets")
struct BudgetTests {
    @Test("States at the exact thresholds", arguments: [
        ("0", BudgetState.normal), ("79.99", .normal), ("80", .nearLimit), ("80.01", .nearLimit),
        ("99.99", .nearLimit), ("100", .over), ("100.01", .over), ("250", .over),
    ])
    func thresholds(spent: String, state: BudgetState) {
        #expect(BudgetState(spent: decimal(spent), limit: 100) == state)
    }

    @Test("Thresholds on an awkward limit are exact to the cent")
    func awkwardLimit() {
        // 80 % of 333,33 is 266,664.
        #expect(BudgetState(spent: decimal("266.66"), limit: decimal("333.33")) == .normal)
        #expect(BudgetState(spent: decimal("266.67"), limit: decimal("333.33")) == .nearLimit)
        #expect(BudgetState(spent: decimal("333.32"), limit: decimal("333.33")) == .nearLimit)
        #expect(BudgetState(spent: decimal("333.33"), limit: decimal("333.33")) == .over)
        // 79,99 % and 80 % as fractions.
        let status = { (spent: String) in
            BudgetStatus(budgetID: UUID(), categoryID: UUID(), space: .pro, limit: 10_000, spent: decimal(spent), daysLeft: nil)
        }
        #expect(status("7999").state == .normal && status("7999").fraction == decimal("0.7999"))
        #expect(status("8000").state == .nearLimit)
        #expect(status("10000").state == .over && status("10000").remaining == 0)
        #expect(status("12000").remaining == -2000)
    }

    @Test("Days left count today, only in the current month")
    func daysLeft() {
        let november = ExpenseGrouping.monthInterval(containing: parisDate(2026, 11, 1), calendar: parisCalendar)
        #expect(BudgetStatus.daysLeft(in: november, now: parisDate(2026, 11, 17), calendar: parisCalendar) == 14)
        #expect(BudgetStatus.daysLeft(in: november, now: parisDate(2026, 11, 30, hour: 23), calendar: parisCalendar) == 1)
        #expect(BudgetStatus.daysLeft(in: november, now: parisDate(2026, 11, 1, hour: 0), calendar: parisCalendar) == 30)
        #expect(BudgetStatus.daysLeft(in: november, now: parisDate(2026, 12, 1), calendar: parisCalendar) == nil)
    }

    @Test("An alert only when a save makes things worse")
    func alerts() {
        func status(_ spent: Int) -> BudgetStatus {
            BudgetStatus(budgetID: UUID(), categoryID: UUID(), space: .personal, limit: 100, spent: Decimal(spent), daysLeft: 3)
        }
        #expect(BudgetService.alert(before: status(10), after: status(85))?.state == .nearLimit)
        #expect(BudgetService.alert(before: status(85), after: status(101))?.state == .over)
        #expect(BudgetService.alert(before: status(10), after: status(101))?.state == .over)
        #expect(BudgetService.alert(before: nil, after: status(90))?.state == .nearLimit)
        #expect(BudgetService.alert(before: status(85), after: status(90)) == nil)
        #expect(BudgetService.alert(before: status(120), after: status(130)) == nil)
        #expect(BudgetService.alert(before: status(120), after: status(50)) == nil)
        #expect(BudgetService.alert(before: status(10), after: status(20)) == nil)
        #expect(BudgetService.alert(before: status(10), after: nil) == nil)
    }

    // MARK: With a store

    @MainActor
    static func setUp() throws -> (ModelContainer, ExpenseCategory, ExpenseCategory) {
        let container = try makeTestContainer()
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)
        let fetch = { (key: String) in
            try #require(try context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.seedKey == key })).first)
        }
        return (container, try fetch("category.personal.groceries"), try fetch("category.pro.meals"))
    }

    @MainActor
    @Test("One budget per category: setting it again updates it")
    func onePerCategory() throws {
        let (container, groceries, _) = try Self.setUp()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let first = try BudgetService.setBudget(400, for: groceries, in: context)
        let second = try BudgetService.setBudget(decimal("350.005"), for: groceries, in: context)
        #expect(first === second)
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 1)
        #expect(second.monthlyAmount == decimal("350.01"))
        #expect(throws: BudgetService.ValidationError.amountNotPositive) { try BudgetService.setBudget(0, for: groceries, in: context) }
        #expect(throws: BudgetService.ValidationError.amountTooLarge) {
            try BudgetService.setBudget(MoneyParser.maximum + 1, for: groceries, in: context)
        }
        try BudgetService.delete(second, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 0)
    }

    @MainActor
    @Test("Status from the store and from the Summary agree; a save that crosses 80 % and 100 % alerts")
    func statusAndAlert() throws {
        let (container, groceries, meals) = try Self.setUp()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try BudgetService.setBudget(100, for: groceries, in: context)
        try BudgetService.setBudget(50, for: meals, in: context)
        let now = parisDate(2026, 11, 17)
        let save = { (amount: String, category: ExpenseCategory) -> BudgetAlert? in
            let before = try BudgetService.status(of: category, at: now, in: context, now: now, calendar: parisCalendar)
            try ExpenseService.create(from: ExpenseDraft(amount: decimal(amount), date: now, space: category.space, category: category), in: context)
            let after = try BudgetService.status(of: category, at: now, in: context, now: now, calendar: parisCalendar)
            return BudgetService.alert(before: before, after: after)
        }
        #expect(try save("79.99", groceries) == nil)
        #expect(try save("0.01", groceries)?.state == .nearLimit)
        #expect(try save("19.99", groceries) == nil)
        #expect(try save("0.01", groceries) == BudgetAlert(categoryID: groceries.id, state: .over, spent: 100, limit: 100))
        // Last month does not count.
        try ExpenseService.create(from: ExpenseDraft(amount: 500, date: parisDate(2026, 10, 31, hour: 23),
                                                     space: .pro, category: meals), in: context)
        #expect(try save("10", meals) == nil)

        let month = ExpenseGrouping.monthInterval(containing: now, calendar: parisCalendar)
        let figures = try SummaryService.figures(around: month, in: context, calendar: parisCalendar)
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let all = BudgetService.statuses(budgets, figures: figures, month: month, space: .all, now: now, calendar: parisCalendar)
        #expect(all.map(\.categoryID) == [groceries.id, meals.id])
        #expect(all.map(\.spent) == [100, 10])
        #expect(all.allSatisfy { $0.daysLeft == 14 })
        #expect(BudgetService.statuses(budgets, figures: figures, month: month, space: .pro, now: now, calendar: parisCalendar)
            .map(\.categoryID) == [meals.id])
        let october = ExpenseGrouping.monthInterval(containing: parisDate(2026, 10, 5), calendar: parisCalendar)
        let past = BudgetService.statuses(budgets, figures: try SummaryService.figures(around: october, in: context, calendar: parisCalendar),
                                          month: october, space: .pro, now: now, calendar: parisCalendar)
        #expect(past.first?.state == .over && past.first?.daysLeft == nil)
    }
}
