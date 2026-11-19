import Foundation
import SwiftData
import Testing
@testable import BifazModels

@Suite("Recurring expenses")
struct RecurringTests {
    static let cal = parisCalendar

    static func days(_ dates: [Date]) -> [String] {
        dates.map { date in
            let c = cal.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
    }

    // MARK: Calendar

    @Test("Monthly from the 31st: last day of short months, back to the 31st after")
    func monthly31() {
        let dates = RecurrenceCalendar.occurrences(start: parisDate(2026, 1, 31), end: nil, frequency: .monthly,
                                                   from: parisDate(2026, 1, 1), through: parisDate(2026, 7, 31), calendar: Self.cal)
        #expect(Self.days(dates) == ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31", "2026-06-30", "2026-07-31"])
    }

    @Test("Yearly from 29 February: the 28th in common years, the 29th in leap years")
    func leapDay() {
        let dates = RecurrenceCalendar.occurrences(start: parisDate(2024, 2, 29), end: nil, frequency: .yearly,
                                                   from: parisDate(2024, 1, 1), through: parisDate(2028, 12, 31), calendar: Self.cal)
        #expect(Self.days(dates) == ["2024-02-29", "2025-02-28", "2026-02-28", "2027-02-28", "2028-02-29"])
    }

    @Test("Weekly and quarterly, with an end date")
    func weeklyQuarterly() {
        let weekly = RecurrenceCalendar.occurrences(start: parisDate(2026, 3, 25), end: parisDate(2026, 4, 15), frequency: .weekly,
                                                    from: parisDate(2026, 3, 1), through: parisDate(2026, 12, 31), calendar: Self.cal)
        // Across the switch to summer time (29 March).
        #expect(Self.days(weekly) == ["2026-03-25", "2026-04-01", "2026-04-08", "2026-04-15"])
        let quarterly = RecurrenceCalendar.occurrences(start: parisDate(2025, 11, 30), end: nil, frequency: .quarterly,
                                                       from: parisDate(2026, 1, 1), through: parisDate(2026, 12, 31), calendar: Self.cal)
        #expect(Self.days(quarterly) == ["2026-02-28", "2026-05-30", "2026-08-30", "2026-11-30"])
    }

    @Test("Next occurrence, and none after the end")
    func next() {
        let next = RecurrenceCalendar.next(onOrAfter: parisDate(2026, 11, 17), start: parisDate(2026, 1, 31), end: nil,
                                           frequency: .monthly, calendar: Self.cal)
        #expect(next.map { Self.days([$0]) } == ["2026-11-30"])
        #expect(RecurrenceCalendar.next(onOrAfter: parisDate(2026, 12, 1), start: parisDate(2026, 1, 31), end: parisDate(2026, 11, 30),
                                        frequency: .monthly, calendar: Self.cal) == nil)
        // Before the start: the start.
        #expect(RecurrenceCalendar.next(onOrAfter: parisDate(2026, 1, 1), start: parisDate(2026, 3, 5), end: nil,
                                        frequency: .weekly, calendar: Self.cal) == Self.cal.startOfDay(for: parisDate(2026, 3, 5)))
    }

    @Test("Monthly equivalent", arguments: [
        (RecurrenceFrequency.weekly, "10", "43.33"), (.monthly, "71.99", "71.99"), (.quarterly, "100", "33.33"), (.yearly, "120", "10"),
    ])
    func monthlyEquivalent(frequency: RecurrenceFrequency, amount: String, expected: String) {
        #expect(RecurrenceCalendar.monthlyEquivalent(of: decimal(amount), frequency: frequency) == decimal(expected))
    }

    // MARK: Generation

    @MainActor
    static func setUp() throws -> (ModelContainer, ExpenseCategory) {
        let container = try makeTestContainer()
        try CategorySeeder.seedIfNeeded(in: container.mainContext)
        let software = try #require(try container.mainContext.fetch(FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.seedKey == "category.pro.software" })).first)
        return (container, software)
    }

    @MainActor
    static func adobe(_ category: ExpenseCategory, start: Date, in context: ModelContext, client: Tag? = nil) throws -> RecurringRule {
        var draft = ExpenseDraft(amount: decimal("71.99"), merchant: "Adobe", space: .pro, category: category, vatRate: .standard)
        draft.client = client
        return try RecurringService.create(.init(draft: draft, frequency: .monthly, startDate: start), in: context,
                                           now: start, calendar: Self.cal)
    }

    @MainActor
    @Test("Catches up every missed month, once; Pro expenses wait for their invoice")
    func catchUp() throws {
        let (container, software) = try Self.setUp()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let client = try TagService.create("Studio Nord", kind: .client, in: context)
        let rule = try Self.adobe(software, start: parisDate(2026, 9, 15), in: context, client: client)

        let created = try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 17), calendar: Self.cal)
        #expect(Self.days(created.compactMap(\.recurrenceDate)).sorted() == ["2026-09-15", "2026-10-15", "2026-11-15"])
        for expense in created {
            #expect(expense.amount == decimal("71.99") && expense.amountInEUR == decimal("71.99"))
            #expect(expense.status == .receiptPending)
            #expect(expense.source == .recurring)
            #expect(expense.recurringRule === rule)
            #expect(expense.vatAmount == decimal("12.00"))
            #expect(expense.client === client)
            #expect(expense.category === software)
        }
        #expect(Self.days([rule.nextDate]) == ["2026-12-15"])

        // Opening again, even twice in a row: nothing new.
        #expect(try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 17, hour: 18), calendar: Self.cal).isEmpty)
        #expect(try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 18), calendar: Self.cal).isEmpty)

        // A generated expense the user deleted does not come back.
        let october = try #require(created.first { Self.days([$0.recurrenceDate!]) == ["2026-10-15"] })
        try ExpenseService.delete(october, in: context)
        #expect(try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 20), calendar: Self.cal).isEmpty)

        // The next month comes on its day.
        let december = try RecurringService.generateDue(in: context, now: parisDate(2026, 12, 15, hour: 8), calendar: Self.cal)
        #expect(Self.days(december.compactMap(\.recurrenceDate)) == ["2026-12-15"])
        #expect(try context.fetchCount(FetchDescriptor<Expense>()) == 3)
    }

    @MainActor
    @Test("Same rule and day, same expense: a second device would not duplicate it")
    func idempotentAcrossDevices() throws {
        let (container, software) = try Self.setUp()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let rule = try Self.adobe(software, start: parisDate(2026, 10, 1), in: context)
        let id = RecurringService.expenseID(rule: rule.id, date: parisDate(2026, 10, 1), calendar: Self.cal)
        #expect(id == RecurringService.expenseID(rule: rule.id, date: parisDate(2026, 10, 1, hour: 23), calendar: Self.cal))
        #expect(id != RecurringService.expenseID(rule: rule.id, date: parisDate(2026, 11, 1), calendar: Self.cal))

        _ = try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 2), calendar: Self.cal)
        // Another device that never ran the rule (no watermark) finds the same expenses already there.
        rule.generatedThrough = nil
        #expect(try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 2), calendar: Self.cal).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<Expense>()) == 2)
    }

    @MainActor
    @Test("Paused occurrences are skipped; editing changes only what comes next")
    func pauseAndEdit() throws {
        let (container, software) = try Self.setUp()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let rule = try Self.adobe(software, start: parisDate(2026, 9, 15), in: context)
        let first = try RecurringService.generateDue(in: context, now: parisDate(2026, 9, 20), calendar: Self.cal)
        #expect(first.count == 1)

        try RecurringService.setPaused(rule, true, in: context, now: parisDate(2026, 9, 21), calendar: Self.cal)
        #expect(try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 20), calendar: Self.cal).isEmpty)
        try RecurringService.setPaused(rule, false, in: context, now: parisDate(2026, 11, 20), calendar: Self.cal)
        #expect(Self.days([rule.nextDate]) == ["2026-12-15"])
        #expect(try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 20), calendar: Self.cal).isEmpty)

        var template = RecurringService.Template(rule: rule)
        template.draft.amount = decimal("79.99")
        try RecurringService.update(rule, with: template, in: context, now: parisDate(2026, 11, 20), calendar: Self.cal)
        let december = try RecurringService.generateDue(in: context, now: parisDate(2026, 12, 15), calendar: Self.cal)
        #expect(december.map(\.amount) == [decimal("79.99")])
        #expect(first.first?.amount == decimal("71.99"))

        // Deleting the rule keeps its expenses.
        try RecurringService.delete(rule, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Expense>()) == 2)
        #expect(december.first?.recurringRule == nil)
    }

    @MainActor
    @Test("Personal rules: confirmed, no tags; foreign currency and ends before start are refused")
    func personalAndValidation() throws {
        let (container, _) = try Self.setUp()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let client = try TagService.create("ACME", kind: .client, in: context)
        var draft = ExpenseDraft(amount: 9, merchant: "Spotify", space: .personal)
        draft.client = client
        _ = try RecurringService.create(.init(draft: draft, frequency: .monthly, startDate: parisDate(2026, 11, 1)), in: context,
                                        now: parisDate(2026, 11, 1), calendar: Self.cal)
        let created = try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 2), calendar: Self.cal)
        #expect(created.first?.status == .confirmed)
        #expect(created.first?.tags?.isEmpty == true)

        var usd = ExpenseDraft(amount: 10, space: .pro)
        usd.currencyCode = "USD"
        #expect(throws: RecurringService.ValidationError.foreignCurrency) {
            try RecurringService.create(.init(draft: usd, frequency: .monthly, startDate: .now), in: context)
        }
        #expect(throws: RecurringService.ValidationError.endBeforeStart) {
            try RecurringService.create(.init(draft: ExpenseDraft(amount: 1), frequency: .monthly,
                                              startDate: parisDate(2026, 5, 1), endDate: parisDate(2026, 4, 1)), in: context, calendar: Self.cal)
        }
    }
}

/// "Repeat" on a new expense (phase 5): the expense and its rule are saved together or not at all.
@Suite("New expense with its repeat rule")
struct RepeatOnCreateTests {
    static let usd = ExchangeRateQuote(currencyCode: "USD", rate: decimal("1.0989"), date: parisDate(2026, 11, 17), source: .ecb)

    @MainActor
    private func counts(_ context: ModelContext) throws -> (expenses: Int, rules: Int) {
        (try context.fetchCount(FetchDescriptor<Expense>()), try context.fetchCount(FetchDescriptor<RecurringRule>()))
    }

    @Test("Success: the expense and a rule starting the next period, in one save")
    @MainActor
    func success() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let draft = ExpenseDraft(amount: 15, merchant: "Gym Club", date: parisDate(2026, 11, 19), space: .personal)
        let created = try ExpenseService.create(from: draft, repeating: .monthly, in: context,
                                                now: parisDate(2026, 11, 19), calendar: parisCalendar)
        #expect(created.expense.amount == 15)
        let rule = try #require(created.rule)
        #expect(rule.merchant == "Gym Club" && rule.amount == 15 && rule.frequency == .monthly)
        #expect(parisCalendar.isDate(rule.startDate, inSameDayAs: parisDate(2026, 12, 19)))
        #expect(parisCalendar.isDate(rule.nextDate, inSameDayAs: parisDate(2026, 12, 19)))
        #expect(!context.hasChanges)
        #expect(try counts(context) == (1, 1))
        // Nothing due today: today's occurrence is the expense just saved.
        #expect(try RecurringService.generateDue(in: context, now: parisDate(2026, 11, 19), calendar: parisCalendar).isEmpty)
    }

    @Test("An invalid rule saves nothing: no expense, no rule")
    @MainActor
    func invalidRule() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var draft = ExpenseDraft(amount: 48, merchant: "GitHub", space: .pro)
        draft.currencyCode = "USD"
        draft.exchangeRate = Self.usd
        #expect(draft.validate() == nil)
        #expect(throws: RecurringService.ValidationError.foreignCurrency) {
            try ExpenseService.create(from: draft, repeating: .monthly, in: context)
        }
        #expect(!context.hasChanges)
        #expect(try counts(context) == (0, 0))
    }

    @Test("An invalid expense saves nothing either")
    @MainActor
    func invalidExpense() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        #expect(throws: (any Error).self) {
            try ExpenseService.create(from: ExpenseDraft(amount: nil), repeating: .weekly, in: context)
        }
        #expect(try counts(context) == (0, 0))
    }

    @Test("Without a frequency it is a plain expense")
    @MainActor
    func noRepeat() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let created = try ExpenseService.create(from: ExpenseDraft(amount: 4.2, space: .personal), repeating: nil, in: context)
        #expect(created.rule == nil)
        #expect(try counts(context) == (1, 0))
    }
}
