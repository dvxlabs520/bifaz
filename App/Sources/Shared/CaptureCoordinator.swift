import SwiftUI
import BifazModels

/// App-wide navigation state shared by the tabs: which tab is selected and
/// whether the new-expense sheet is up. Injected with `.environment`.
@Observable
final class AppNavigation {
    var selectedTab: AppTab = AppTab.initial
    /// Non-nil while the quick-add sheet is presented; carries the default space.
    var newExpenseSpace: Space?

    /// Opens quick add, defaulting to the space of the current filter.
    func addExpense(filter: SpaceFilter) {
        newExpenseSpace = filter.space ?? .personal
    }
}
