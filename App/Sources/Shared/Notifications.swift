import SwiftUI
import SwiftData
import UserNotifications
import BifazModels

/// Local notifications (phase 4): permission, scheduling from `ReminderPlanner`
/// and taps. Everything is off until the user turns a reminder on in Settings;
/// permission is asked at that moment, never at launch.
@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    /// Identifiers Bifaz owns (so rescheduling never touches anything else).
    static let prefix = "bifaz."

    private let center = UNUserNotificationCenter.current()
    /// Set by the root view: where a tapped notification leads.
    var onRoute: ((ReminderRoute) -> Void)?

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Asks the system once; later calls return the stored answer.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces every scheduled Bifaz reminder by the current plan.
    func reschedule(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) async {
        let settings = ReminderSettingsStore.load()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let status = await authorizationStatus()
        guard settings.vatDeadlineEnabled || settings.recurringEnabled,
              status == .authorized || status == .provisional else { return }

        let isVATRegistered = AppDefaults.shared.object(forKey: VATSetting.key) as? Bool ?? VATSetting.defaultValue
        let rules = ((try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []).map {
            (id: $0.id, merchant: $0.merchant, amount: $0.amount, currencyCode: $0.currencyCode, nextDate: $0.nextDate, isActive: $0.isActive)
        }
        let plan = ReminderPlanner.plan(
            settings: settings, isVATRegistered: isVATRegistered, rules: rules,
            vatPaid: { period in
                (try? ExpenseFilter(space: .pro, dateInterval: period).fetch(in: context)).map { ExpenseTotals($0).proVAT }
            },
            now: now, calendar: calendar
        )
        for reminder in plan { await add(reminder, context: context, calendar: calendar) }
    }

    /// Budgets crossed by expenses created without the user (recurring generation).
    func post(_ alerts: [BudgetAlert], in context: ModelContext) async {
        let settings = ReminderSettingsStore.load()
        guard settings.budgetEnabled, await authorizationStatus() == .authorized else { return }
        for reminder in ReminderPlanner.budgetAlerts(alerts, settings: settings, now: .now, calendar: .current) {
            await add(reminder, context: context, calendar: .current)
        }
    }

    private func add(_ reminder: PlannedReminder, context: ModelContext, calendar: Calendar) async {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo = ["route": reminder.route.rawValue]
        switch reminder.kind {
        case .vatDeadline(let due, let period, let vat):
            content.title = String(localized: "notification.vat.title")
            let dueText = due.formatted(.dateTime.day().month(.wide))
            let periodText = period.start.formatted(.dateTime.month(.wide).year())
            if let vat {
                content.body = String(localized: "notification.vat.body.amount \(periodText) \(vat.formatted(.currency(code: "EUR"))) \(dueText)")
            } else {
                content.body = String(localized: "notification.vat.body.generic \(periodText) \(dueText)")
            }
        case .recurring(_, let merchant, let amount, let currencyCode):
            content.title = String(localized: "notification.recurring.title")
            let name = merchant.isEmpty ? String(localized: "expense.untitled") : merchant
            content.body = String(localized: "notification.recurring.body \(name) \(amount.formatted(.currency(code: currencyCode)))")
        case .budget(let categoryID, let state, let spent, let limit):
            let descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.id == categoryID })
            let name = (try? context.fetch(descriptor).first?.displayName) ?? ""
            content.title = state == .over
                ? String(localized: "notification.budget.over.title \(name)")
                : String(localized: "notification.budget.near.title \(name)")
            content.body = String(localized: "notification.budget.body \(spent.formatted(.currency(code: "EUR"))) \(limit.formatted(.currency(code: "EUR")))")
        }
        let trigger: UNNotificationTrigger? = reminder.fireDate.map { date in
            UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false
            )
        }
        let request = UNNotificationRequest(identifier: Self.prefix + reminder.id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: Delegate

    func install() {
        center.delegate = self
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["route"] as? String,
              let route = ReminderRoute(rawValue: raw) else { return }
        await MainActor.run { self.onRoute?(route) }
    }
}
