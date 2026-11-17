import Foundation
import Testing
@testable import BifazModels

@Suite("Reminders")
struct ReminderTests {
    static let cal = parisCalendar

    static func key(_ date: Date?) -> String {
        guard let date else { return "now" }
        let c = cal.dateComponents([.year, .month, .day, .hour], from: date)
        return String(format: "%04d-%02d-%02d %02dh", c.year!, c.month!, c.day!, c.hour!)
    }

    static func settings(_ period: ReminderSettings.VATPeriod, day: Int = 19, lead: Int = 3) -> ReminderSettings {
        var settings = ReminderSettings()
        settings.vatDeadlineEnabled = true
        settings.vatPeriod = period
        settings.vatDueDay = day
        settings.vatLeadDays = lead
        return settings
    }

    @Test("Everything is off by default")
    func defaults() {
        let settings = ReminderSettings()
        #expect(!settings.anyEnabled)
        #expect(ReminderPlanner.plan(settings: settings, isVATRegistered: true, rules: [], vatPaid: { _ in 1 },
                                     now: parisDate(2026, 11, 17), calendar: Self.cal).isEmpty)
    }

    @Test("Monthly VAT: due on the day, reminded days before, for the previous month")
    func monthly() {
        let deadlines = ReminderPlanner.vatDeadlines(settings: Self.settings(.monthly), now: parisDate(2026, 11, 17), calendar: Self.cal)
        // 16 November 9:00 has passed: December and January.
        #expect(deadlines.map { Self.key($0.fire) } == ["2026-12-16 09h", "2027-01-16 09h"])
        #expect(deadlines.map { Self.key($0.due) } == ["2026-12-19 00h", "2027-01-19 00h"])
        #expect(deadlines.first?.period == ExpenseGrouping.monthInterval(containing: parisDate(2026, 11, 15), calendar: Self.cal))
        // Still before the reminder: this month.
        let early = ReminderPlanner.vatDeadlines(settings: Self.settings(.monthly), now: parisDate(2026, 11, 16, hour: 8), calendar: Self.cal)
        #expect(Self.key(early.first?.fire) == "2026-11-16 09h")
    }

    @Test("Quarterly VAT: January, April, July, October, for the previous quarter")
    func quarterly() {
        let deadlines = ReminderPlanner.vatDeadlines(settings: Self.settings(.quarterly, day: 24, lead: 5),
                                                     now: parisDate(2026, 11, 17), calendar: Self.cal)
        #expect(deadlines.map { Self.key($0.fire) } == ["2027-01-19 09h", "2027-04-19 09h"])
        #expect(deadlines.first?.period.start == ExpenseGrouping.monthInterval(containing: parisDate(2026, 10, 2), calendar: Self.cal).start)
        #expect(deadlines.first?.period.end == ExpenseGrouping.monthInterval(containing: parisDate(2027, 1, 2), calendar: Self.cal).start)
    }

    @Test("The VAT of the period goes in when the period is over; nothing without Sujeto a TVA")
    func vatContent() {
        var asked: [DateInterval] = []
        let plan = ReminderPlanner.plan(settings: Self.settings(.monthly), isVATRegistered: true, rules: [],
                                        vatPaid: { asked.append($0); return decimal("123.45") },
                                        now: parisDate(2026, 12, 2), calendar: Self.cal)
        guard case .vatDeadline(_, let period, let vat) = plan.first?.kind else { Issue.record("no VAT reminder"); return }
        #expect(vat == decimal("123.45"))
        #expect(asked == [period])
        #expect(plan.first?.route == .vatSummary)
        // January's reminder is for December, not over yet: generic text.
        guard case .vatDeadline(_, _, let later) = plan.last?.kind else { return }
        #expect(later == nil)
        #expect(ReminderPlanner.plan(settings: Self.settings(.monthly), isVATRegistered: false, rules: [], vatPaid: { _ in 1 },
                                     now: parisDate(2026, 12, 2), calendar: Self.cal).isEmpty)
    }

    @Test("Recurring reminders at 9:00 on each rule's next day, future only, paused rules left out")
    func recurring() {
        var settings = ReminderSettings()
        settings.recurringEnabled = true
        let a = UUID(), b = UUID(), c = UUID()
        let plan = ReminderPlanner.plan(
            settings: settings, isVATRegistered: true,
            rules: [
                (a, "Adobe", decimal("71.99"), "EUR", parisCalendar.startOfDay(for: parisDate(2026, 12, 15)), true),
                (b, "Loyer", 900, "EUR", parisCalendar.startOfDay(for: parisDate(2026, 11, 17)), true),
                (c, "Gym", 30, "EUR", parisCalendar.startOfDay(for: parisDate(2026, 12, 1)), false),
            ],
            vatPaid: { _ in nil }, now: parisDate(2026, 11, 17, hour: 10), calendar: Self.cal
        )
        #expect(plan.map { Self.key($0.fireDate) } == ["2026-12-15 09h"])
        #expect(plan.first?.route == .recurringRule(a))
        #expect(plan.first?.id == "rule-\(a.uuidString)-20261215")
    }

    @Test("Budget notifications only when switched on")
    func budgets() {
        let alert = BudgetAlert(categoryID: UUID(), state: .over, spent: 120, limit: 100)
        #expect(ReminderPlanner.budgetAlerts([alert], settings: ReminderSettings(), now: .now, calendar: Self.cal).isEmpty)
        var settings = ReminderSettings()
        settings.budgetEnabled = true
        let planned = ReminderPlanner.budgetAlerts([alert], settings: settings, now: .now, calendar: Self.cal)
        #expect(planned.count == 1 && planned.first?.fireDate == nil && planned.first?.route == .budgets)
    }

    @Test("Routes survive the notification's user info", arguments: [
        ReminderRoute.vatSummary, .budgets, .recurringRule(UUID()),
    ])
    func routes(route: ReminderRoute) {
        #expect(ReminderRoute(rawValue: route.rawValue) == route)
        #expect(ReminderRoute(rawValue: "rule:nope") == nil)
    }
}
