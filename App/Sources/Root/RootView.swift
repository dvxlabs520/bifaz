import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Tab bar: Summary · Expenses · Assistant · Settings, plus the quick-add sheet.
struct RootView: View {
    @State private var navigation = AppNavigation()
    /// Global space filter, shared by every screen and kept between launches.
    @AppStorage("spaceFilter") private var spaceFilter: SpaceFilter = .all

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
        .environment(navigation)
        .sheet(item: $navigation.newExpenseSpace) { space in
            ExpenseFormView(defaultSpace: space)
        }
        .receiptCapture(source: $navigation.captureSource) { receipt in
            navigation.confirm(receipt)
        }
        .sheet(item: $navigation.capturedReceipt) { result in
            ExpenseFormView(capture: result.receipt, defaultSpace: result.space)
        }
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
