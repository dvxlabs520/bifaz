import SwiftUI

/// The four tabs of Bifaz.
enum AppTab: String, Hashable, CaseIterable {
    case summary
    case expenses
    case assistant
    case settings
}

extension AppTab {
    /// The tab shown at launch. Debug builds accept `-BifazInitialTab <tab>`
    /// (e.g. `settings`) so screenshots can be taken without UI automation.
    static var initial: AppTab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "BifazInitialTab"),
           let tab = AppTab(rawValue: raw) {
            return tab
        }
        #endif
        return .summary
    }
}
