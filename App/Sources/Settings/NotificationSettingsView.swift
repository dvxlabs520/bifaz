import SwiftUI
import UIKit
import UserNotifications
import BifazModels
import BifazDesign

/// Settings > Notifications: the three local reminders. Permission is asked only
/// when the user turns a reminder on, never at launch or on appear.
struct NotificationSettingsView: View {
    @AppStorage(ReminderSettingsStore.key) private var settings = ReminderSettings()
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @State private var status: UNAuthorizationStatus?

    private let onChange: () -> Void

    init(onChange: @escaping () -> Void = {}) {
        self.onChange = onChange
    }

    private var isDenied: Bool { status == .denied }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isDenied { deniedBlock }
                vatSection
                recurringSection
                budgetSection
                Text("reminders.footer", tableName: "Reminders")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
                    .padding(.top, BifazSpacing.xl)
            }
            .padding(.horizontal, BifazSpacing.screen)
            .padding(.top, BifazSpacing.xs)
            .padding(.bottom, BifazSpacing.xl)
        }
        .navigationTitle(Text("reminders.title", tableName: "Reminders"))
        .navigationBarTitleDisplayMode(.inline)
        .bifazScreen()
        .task { status = await NotificationScheduler.shared.authorizationStatus() }
    }

    // MARK: Sections

    private var vatSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
            toggleRow("reminders.vat.toggle", isOn: vatBinding, id: "ui.reminderVAT")
                .disabled(!isVATRegistered)
            if isVATRegistered, settings.vatDeadlineEnabled {
                vatDetails
            }
            HairlineDivider()
            if !isVATRegistered {
                caption("reminders.vat.needsVAT")
            }
        }
        .padding(.top, BifazSpacing.s)
    }

    private var vatDetails: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
                FilterChip(LocalizedStringResource("reminders.vat.monthly", table: "Reminders"),
                           isSelected: settings.vatPeriod == .monthly) {
                    update { $0.vatPeriod = .monthly }
                }
                FilterChip(LocalizedStringResource("reminders.vat.quarterly", table: "Reminders"),
                           isSelected: settings.vatPeriod == .quarterly) {
                    update { $0.vatPeriod = .quarterly }
                }
            }
            Stepper(value: Binding(get: { settings.vatDueDay }, set: { value in update { $0.vatDueDay = value } }), in: 1...28) {
                Text("reminders.vat.day \(settings.vatDueDay)", tableName: "Reminders")
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInk)
                    .monospacedDigit()
            }
            .frame(minHeight: 44)
            Stepper(value: Binding(get: { settings.vatLeadDays }, set: { value in update { $0.vatLeadDays = value } }), in: 1...10) {
                Text("reminders.vat.lead \(settings.vatLeadDays)", tableName: "Reminders")
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInk)
                    .monospacedDigit()
            }
            .frame(minHeight: 44)
            nextReminderCaption
        }
        .padding(.bottom, BifazSpacing.s)
    }

    @ViewBuilder
    private var nextReminderCaption: some View {
        if let next = ReminderPlanner.vatDeadlines(settings: settings, now: .now, calendar: .current, count: 1).first {
            let when = next.fire.formatted(.dateTime.day().month(.wide).hour().minute())
            let first = next.period.start.formatted(.dateTime.month(.wide))
            if settings.vatPeriod == .monthly {
                Text("reminders.vat.next.monthly \(when) \(first)", tableName: "Reminders")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            } else {
                let last = (Calendar.current.date(byAdding: .day, value: -1, to: next.period.end) ?? next.period.end)
                    .formatted(.dateTime.month(.wide))
                Text("reminders.vat.next.quarterly \(when) \(first) \(last)", tableName: "Reminders")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            }
        }
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
            toggleRow("reminders.recurring.toggle", isOn: recurringBinding, id: "ui.reminderRecurring")
            HairlineDivider()
            caption("reminders.recurring.caption")
        }
        .padding(.top, BifazSpacing.xl)
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
            toggleRow("reminders.budget.toggle", isOn: budgetBinding, id: "ui.reminderBudget")
            HairlineDivider()
            caption("reminders.budget.caption")
        }
        .padding(.top, BifazSpacing.xl)
    }

    private var deniedBlock: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            Text("reminders.denied.title", tableName: "Reminders")
                .font(.bifazBody.weight(.semibold))
                .foregroundStyle(.bifazInk)
            Text("reminders.denied.body", tableName: "Reminders")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("reminders.denied.button", tableName: "Reminders")
                    .font(.bifazBody.weight(.semibold))
                    .foregroundStyle(.bifazInk)
                    .underline()
                    .frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("ui.reminderOpenSettings")
        }
        .padding(.top, BifazSpacing.s)
        .padding(.bottom, BifazSpacing.xs)
        .accessibilityElement(children: .contain)
    }

    // MARK: Rows

    private func toggleRow(_ key: LocalizedStringKey, isOn: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: isOn) {
            Text(key, tableName: "Reminders")
                .font(.bifazBody)
                .foregroundStyle(.bifazInk)
        }
        .tint(.bifazInk)
        .padding(.vertical, BifazSpacing.xs)
        .frame(minHeight: 44)
        .accessibilityIdentifier(id)
    }

    private func caption(_ key: LocalizedStringKey) -> some View {
        Text(key, tableName: "Reminders")
            .font(.bifazCaption)
            .foregroundStyle(.bifazInkSecondary)
            .padding(.top, BifazSpacing.s)
    }

    // MARK: State

    private var vatBinding: Binding<Bool> {
        Binding(get: { settings.vatDeadlineEnabled && isVATRegistered },
                set: { value in toggle(value) { $0.vatDeadlineEnabled = value } })
    }
    private var recurringBinding: Binding<Bool> {
        Binding(get: { settings.recurringEnabled }, set: { value in toggle(value) { $0.recurringEnabled = value } })
    }
    private var budgetBinding: Binding<Bool> {
        Binding(get: { settings.budgetEnabled }, set: { value in toggle(value) { $0.budgetEnabled = value } })
    }

    private func update(_ change: (inout ReminderSettings) -> Void) {
        var copy = settings
        change(&copy)
        settings = copy
        onChange()
    }

    /// Turning on asks for permission when it was never asked; if refused, the toggle goes back off.
    private func toggle(_ value: Bool, _ change: @escaping (inout ReminderSettings) -> Void) {
        guard value else { update(change); return }
        Task {
            var current = await NotificationScheduler.shared.authorizationStatus()
            if current == .notDetermined {
                current = await NotificationScheduler.shared.requestAuthorization() ? .authorized : .denied
            }
            status = current
            guard current != .denied else { return }
            update(change)
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    NavigationStack { NotificationSettingsView() }
}

#Preview("Dark") {
    NavigationStack { NotificationSettingsView() }
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    NavigationStack { NotificationSettingsView() }
        .dynamicTypeSize(.accessibility3)
}
