import SwiftUI
import BifazModels
import BifazReading

/// App-wide navigation state shared by the tabs: which tab is selected and
/// whether the new-expense sheet is up. Injected with `.environment`.
@Observable
final class AppNavigation {
    var selectedTab: AppTab = AppTab.initial
    /// Non-nil while the quick-add sheet is presented; carries the default space.
    var newExpenseSpace: Space?
    /// Non-nil while the scanner, photo picker or file importer is up.
    var captureSource: CaptureSource?
    /// A read receipt waiting for confirmation.
    var capturedReceipt: CaptureResult?
    /// Space to preselect for a captured receipt (the filter's, when the capture started).
    private var captureSpace: Space = .personal

    /// Opens quick add, defaulting to the space of the current filter.
    func addExpense(filter: SpaceFilter) {
        newExpenseSpace = filter.space ?? .personal
    }

    /// Starts a receipt capture from `source`.
    func capture(from source: CaptureSource, filter: SpaceFilter) {
        captureSpace = filter.space ?? .personal
        captureSource = source
    }

    /// Hands a read receipt to the confirmation screen.
    func confirm(_ receipt: CapturedReceipt) {
        capturedReceipt = CaptureResult(receipt: receipt, space: captureSpace)
    }
}

/// A read receipt plus the space it was captured in, presented as a sheet.
struct CaptureResult: Identifiable {
    let id = UUID()
    let receipt: CapturedReceipt
    let space: Space
}
