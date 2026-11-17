import SwiftUI
import BifazModels
import BifazDesign

/// Tab bar: Summary · Expenses · Assistant · Settings.
struct RootView: View {
    @State private var selectedTab: AppTab = AppTab.initial
    /// Global space filter, shared by every screen and kept between launches.
    @AppStorage("spaceFilter") private var spaceFilter: SpaceFilter = .all

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("tab.summary", systemImage: "chart.pie", value: AppTab.summary) {
                SummaryView(spaceFilter: $spaceFilter)
            }
            Tab("tab.expenses", systemImage: "list.bullet.rectangle", value: AppTab.expenses) {
                ExpensesView(spaceFilter: $spaceFilter)
            }
            Tab("tab.assistant", systemImage: "sparkles", value: AppTab.assistant) {
                AssistantView()
            }
            Tab("tab.settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(.bifazInk)
    }
}

#Preview("Light") {
    RootView()
        .modelContainer(PreviewContainer.empty)
}

#Preview("Dark") {
    RootView()
        .modelContainer(PreviewContainer.empty)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    RootView()
        .modelContainer(PreviewContainer.empty)
        .dynamicTypeSize(.accessibility3)
}
