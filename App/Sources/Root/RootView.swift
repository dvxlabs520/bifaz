import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Tab bar: Summary · Expenses · Assistant · Settings, plus the quick-add sheet.
struct RootView: View {
    @State private var navigation = AppNavigation()
    /// Global space filter, shared by every screen and kept between launches.
    @AppStorage("spaceFilter") private var spaceFilter: SpaceFilter = .all
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab(value: AppTab.summary) {
                SummaryView(spaceFilter: $spaceFilter)
            } label: {
                tabLabel("tab.summary", icon: .summary)
            }
            Tab(value: AppTab.expenses) {
                ExpensesView(spaceFilter: $spaceFilter)
            } label: {
                tabLabel("tab.expenses", icon: .expenses)
            }
            Tab(value: AppTab.assistant) {
                AssistantView()
            } label: {
                tabLabel("tab.assistant", icon: .assistant)
            }
            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                tabLabel("tab.settings", icon: .settings)
            }
        }
        .tint(.bifazInk)
        .overlay(alignment: .top) { budgetBanner }
        .animation(reduceMotion ? nil : .snappy, value: navigation.budgetAlert)
        .sheet(item: $navigation.newExpenseSpace) { space in
            ExpenseFormView(defaultSpace: space)
        }
        .receiptCapture(source: $navigation.captureSource) { receipt in
            navigation.confirm(receipt)
        }
        .sheet(item: $navigation.capturedReceipt) { result in
            ExpenseFormView(capture: result.receipt, defaultSpace: result.space)
        }
        // After the sheets, so the forms they present can reach it too.
        .environment(navigation)
        .task {
            NotificationScheduler.shared.install()
            NotificationScheduler.shared.onRoute = { route in open(route) }
            await runMaintenance()
        }
        .onChange(of: navigation.selectedTab) { navigation.isCaptureButtonHidden = false }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await runMaintenance() } }
        }
    }

    /// On launch and on every return to the foreground: generate the recurring
    /// expenses due (no backend, so this is the moment), notify budgets they
    /// crossed, and reschedule the reminders.
    private func runMaintenance() async {
        do {
            let created = try RecurringService.generateDue(in: context)
            if !created.isEmpty {
                Log.app.notice("Generated \(created.count, privacy: .public) recurring expenses")
                await NotificationScheduler.shared.post(budgetAlerts(for: created), in: context)
            }
        } catch {
            Log.app.error("Recurring generation failed: \(String(describing: type(of: error)), privacy: .public)")
        }
        await NotificationScheduler.shared.reschedule(in: context)
    }

    /// Budgets that the generated expenses pushed near or over their limit.
    private func budgetAlerts(for created: [Expense]) -> [BudgetAlert] {
        var alerts: [BudgetAlert] = []
        let groups = Dictionary(grouping: created.filter { $0.category != nil }) { expense in
            "\(expense.category!.id)|\(ExpenseGrouping.monthInterval(containing: expense.date).start.timeIntervalSince1970)"
        }
        for expenses in groups.values {
            guard let first = expenses.first, let category = first.category,
                  let after = try? BudgetService.status(of: category, at: first.date, in: context) else { continue }
            var before = after
            before.spent -= expenses.reduce(Decimal(0)) { $0 + $1.amountInEUR }
            if let alert = BudgetService.alert(before: before, after: after) { alerts.append(alert) }
        }
        return alerts
    }

    /// Where a tapped notification leads.
    private func open(_ route: ReminderRoute) {
        switch route {
        case .vatSummary:
            spaceFilter = .pro
            navigation.selectedTab = .summary
        case .budgets:
            navigation.selectedTab = .summary
            navigation.summaryPath.append(SummaryRoute.budgets)
        case .recurringRule(let id):
            navigation.selectedTab = .settings
            navigation.settingsPath = NavigationPath([SettingsRoute.recurringRule(id)])
        }
    }

    /// Shown for a few seconds after a save that pushed a budget near or over its limit.
    @ViewBuilder
    private var budgetBanner: some View {
        if let alert = navigation.budgetAlert {
            let name = categoryName(alert.categoryID)
            BudgetAlertBanner(alert: alert, categoryName: name) { navigation.budgetAlert = nil }
                .padding(.horizontal, BifazSpacing.screen)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: alert) {
                    try? await Task.sleep(for: .seconds(1))
                    AccessibilityNotification.Announcement(
                        alert.state == .over
                            ? String(localized: "budget.alert.over.announcement \(name)", table: "Budgets")
                            : String(localized: "budget.alert.near.announcement \(name)", table: "Budgets")
                    ).post()
                    try? await Task.sleep(for: .seconds(5))
                    if navigation.budgetAlert == alert { navigation.budgetAlert = nil }
                }
        }
    }

    private func categoryName(_ id: UUID) -> String {
        let descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor).first?.displayName) ?? ""
    }

    private func tabLabel(_ title: LocalizedStringKey, icon: BifazIcon) -> some View {
        Label {
            Text(title)
        } icon: {
            icon.image
        }
    }
}

#Preview("Light") {
    RootView()
        .modelContainer(PreviewContainer.sample)
}

#Preview("Dark") {
    RootView()
        .modelContainer(PreviewContainer.sample)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    RootView()
        .modelContainer(PreviewContainer.empty)
        .dynamicTypeSize(.accessibility3)
}
