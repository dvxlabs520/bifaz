import Foundation

// Local notifications (phase 4): what to schedule and when, as values. The app
// turns them into `UNNotificationRequest`s with localized text; this file holds
// the calendar logic so it is tested without the notification center.

/// User settings of the three reminders. All off until the user turns them on.
public struct ReminderSettings: Codable, Sendable, Equatable {
    public enum VATPeriod: String, Codable, Sendable, CaseIterable { case monthly, quarterly }

    public var vatDeadlineEnabled = false
    public var vatPeriod: VATPeriod = .monthly
    /// Day of the month the VAT return is due (1…28).
    public var vatDueDay = 19
    /// Days before the due day the reminder fires.
    public var vatLeadDays = 3
    public var recurringEnabled = false
    public var budgetEnabled = false

    public init() {}

    public var anyEnabled: Bool { vatDeadlineEnabled || recurringEnabled || budgetEnabled }
}

/// A notification to schedule.
public struct PlannedReminder: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        /// VAT return due on `dueDate` for the period `period`; `vat` paid in it when already known.
        case vatDeadline(dueDate: Date, period: DateInterval, vat: Decimal?)
        /// A recurring expense expected today.
        case recurring(ruleID: UUID, merchant: String, amount: Decimal, currencyCode: String)
        /// A budget crossed by an expense created without the user (recurring generation).
        case budget(categoryID: UUID, state: BudgetState, spent: Decimal, limit: Decimal)
    }

    /// Stable per occurrence, so rescheduling replaces instead of duplicating.
    public var id: String
    /// When to fire; `nil` = now.
    public var fireDate: Date?
    public var kind: Kind
    /// Where tapping it leads.
    public var route: ReminderRoute
}

/// The screen a notification opens.
public enum ReminderRoute: Sendable, Equatable, Hashable {
    case vatSummary
    case recurringRule(UUID)
    case budgets

    public var rawValue: String {
        switch self {
        case .vatSummary: "vat"
        case .recurringRule(let id): "rule:\(id.uuidString)"
        case .budgets: "budgets"
        }
    }

    public init?(rawValue: String) {
        if rawValue == "vat" { self = .vatSummary; return }
        if rawValue == "budgets" { self = .budgets; return }
        if rawValue.hasPrefix("rule:"), let id = UUID(uuidString: String(rawValue.dropFirst(5))) {
            self = .recurringRule(id); return
        }
        return nil
    }
}

public enum ReminderPlanner {
    /// Reminders fire at 9:00.
    public static let hour = 9
    /// iOS keeps at most 64 pending notifications per app; Bifaz stays well under.
    public static let maxRecurring = 40
    public static let vatDeadlinesAhead = 2

    /// The next VAT due dates after `now` (reminder not yet passed), with the period each one closes.
    /// Monthly: due on `dueDay` of every month, for the previous month.
    /// Quarterly: due on `dueDay` of January, April, July and October, for the previous quarter.
    public static func vatDeadlines(settings: ReminderSettings, now: Date, calendar: Calendar, count: Int = vatDeadlinesAhead)
        -> [(due: Date, period: DateInterval, fire: Date)] {
        let day = min(max(settings.vatDueDay, 1), 28)
        var result: [(Date, DateInterval, Date)] = []
        guard var month = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        var guardCount = 0
        while result.count < count, guardCount < 40 {
            guardCount += 1
            defer { month = calendar.date(byAdding: .month, value: 1, to: month) ?? month }
            let monthNumber = calendar.component(.month, from: month)
            if settings.vatPeriod == .quarterly, ![1, 4, 7, 10].contains(monthNumber) { continue }
            guard let due = calendar.date(byAdding: .day, value: day - 1, to: month),
                  let fireDay = calendar.date(byAdding: .day, value: -max(settings.vatLeadDays, 0), to: due),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: fireDay),
                  fire > now else { continue }
            let length = settings.vatPeriod == .monthly ? 1 : 3
            guard let periodStart = calendar.date(byAdding: .month, value: -length, to: month) else { continue }
            result.append((calendar.startOfDay(for: due), DateInterval(start: periodStart, end: month), fire))
        }
        return result
    }

    /// Everything to schedule from the settings, the rules and the VAT known so far.
    /// `vatPaid` answers the VAT of a closed period (nil when the period is not over yet).
    public static func plan(
        settings: ReminderSettings,
        isVATRegistered: Bool,
        rules: [(id: UUID, merchant: String, amount: Decimal, currencyCode: String, nextDate: Date, isActive: Bool)],
        vatPaid: (DateInterval) -> Decimal?,
        now: Date,
        calendar: Calendar
    ) -> [PlannedReminder] {
        var reminders: [PlannedReminder] = []
        if settings.vatDeadlineEnabled, isVATRegistered {
            for deadline in vatDeadlines(settings: settings, now: now, calendar: calendar) {
                let vat = deadline.period.end <= now ? vatPaid(deadline.period) : nil
                reminders.append(PlannedReminder(
                    id: "vat-\(dayKey(deadline.due, calendar))",
                    fireDate: deadline.fire,
                    kind: .vatDeadline(dueDate: deadline.due, period: deadline.period, vat: vat),
                    route: .vatSummary
                ))
            }
        }
        if settings.recurringEnabled {
            let upcoming = rules
                .filter { $0.isActive && $0.nextDate != .distantFuture }
                .compactMap { rule -> PlannedReminder? in
                    guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: rule.nextDate), fire > now else { return nil }
                    return PlannedReminder(
                        id: "rule-\(rule.id.uuidString)-\(dayKey(rule.nextDate, calendar))",
                        fireDate: fire,
                        kind: .recurring(ruleID: rule.id, merchant: rule.merchant, amount: rule.amount, currencyCode: rule.currencyCode),
                        route: .recurringRule(rule.id)
                    )
                }
                .sorted { ($0.fireDate ?? now) < ($1.fireDate ?? now) }
            reminders += upcoming.prefix(maxRecurring)
        }
        return reminders
    }

    /// Immediate budget notifications for expenses generated without the user.
    public static func budgetAlerts(_ alerts: [BudgetAlert], settings: ReminderSettings, now: Date, calendar: Calendar) -> [PlannedReminder] {
        guard settings.budgetEnabled else { return [] }
        return alerts.map { alert in
            PlannedReminder(
                id: "budget-\(alert.categoryID.uuidString)-\(alert.state.rawValue)-\(dayKey(now, calendar))",
                fireDate: nil,
                kind: .budget(categoryID: alert.categoryID, state: alert.state, spent: alert.spent, limit: alert.limit),
                route: .budgets
            )
        }
    }

    static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
