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
