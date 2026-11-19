import XCTest

/// Automatic accessibility audit (`performAccessibilityAudit`) on the main screens,
/// with the debug sample data, in French (the longest strings). Each screen is reached
/// the same way on every iPhone size (launch argument or a button always on screen)
/// and checked by an identifier before the audit. Known false positives are excluded
/// explicitly below and explained in docs/fase-4-notas.md.
final class AccessibilityAuditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(tab: String = "summary", route: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-BifazUITesting", "YES",
            "-BifazSampleData", "YES",
            "-BifazInitialTab", tab,
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
            "-spaceFilter", "all",
        ]
        if let route { app.launchArguments += ["-BifazInitialRoute", route] }
        app.launch()
        return app
    }

    /// Waits for the screen's own element, lets transitions settle, then audits.
    @MainActor
    private func audit(_ screen: String, in app: XCUIApplication, expecting marker: XCUIElement) throws {
        XCTAssertTrue(marker.waitForExistence(timeout: 10), "\(screen) is on screen before the audit")
        // Mid-transition (tab cross-fade, search bar settling) the audit measures
        // half-faded text: wait until the screen has stopped moving.
        waitUntilStill(marker)
        let search = app.searchFields.firstMatch
        if search.exists { waitUntilStill(search) }
        // At launch the recurring expenses due are generated and inserted into lists with
        // an animation: wait until the rows stop changing.
        waitUntilRowsSettle(in: app)
        sleep(1)
        let screenFrame = app.windows.firstMatch.frame
        let capture = app.buttons["ui.captureButton"]
        let captureFrame = capture.exists ? capture.frame.insetBy(dx: -12, dy: -12) : .null
        try app.performAccessibilityAudit { issue in
            let excluded = Self.isKnownFalsePositive(issue, screen: screenFrame, captureButton: captureFrame)
            print("BIFAZ-AUDIT [\(screen)] \(excluded ? "excluded" : "ISSUE") \(issue.auditType) · \(issue.compactDescription) · \(issue.element?.debugDescription.prefix(160) ?? "-")")
            return excluded
        }
    }

    /// Waits until the element's frame has not changed for a second (10 s at most).
    @MainActor
    private func waitUntilStill(_ element: XCUIElement) {
        var last = element.frame
        var still = 0
        for _ in 0..<40 {
            usleep(250_000)
            let frame = element.frame
            still = frame == last ? still + 1 : 0
            last = frame
            if still >= 4 { return }
        }
    }

    /// Waits until the number of list rows has not changed for 1.5 s and the first row is still.
    @MainActor
    private func waitUntilRowsSettle(in app: XCUIApplication) {
        var last = app.cells.count
        var stable = 0
        for _ in 0..<40 where stable < 6 {
            usleep(250_000)
            let count = app.cells.count
            stable = count == last ? stable + 1 : 0
            last = count
        }
        let first = app.cells.firstMatch
        if first.exists { waitUntilStill(first) }
    }

    /// Explicit exclusions, each one explained in docs/fase-4-notas.md:
    /// 1. Contrast of content passing under the translucent tab bar (bottom 110 pt) or under
    ///    the floating capture button and its shadow: the audit samples pixels through them.
    /// 2. The system navigation bar (top 130 pt): Liquid Glass toolbar buttons
    ///    ("Modifier", "Répéter", "Enregistrer") and the inline title are drawn by iOS;
    ///    their contrast and their Dynamic Type limits are the system's.
    /// 3. "Text clipped" on the history search field (the system's `.searchable` bar): it is
    ///    reported whatever the prompt, even "Rechercher" (10 letters in a 370 pt field).
    /// 4. Dynamic Type of the Tout / Pro / Perso chips: they grow with the text and the
    ///    row becomes a column (`ViewThatFits`, checked by hand at AccessibilityXL); the
    ///    audit reports the swap as "partially unsupported".
    @MainActor
    static func isKnownFalsePositive(_ issue: XCUIAccessibilityAuditIssue, screen: CGRect, captureButton: CGRect) -> Bool {
        guard let element = issue.element else {
            // Contrast issues the audit cannot attach to any element come from the
            // translucent bars (case 1); anything else must be looked at.
            return issue.auditType == .contrast
        }
        let frame = element.frame
        switch issue.auditType {
        case .contrast:
            if frame.maxY > screen.maxY - 110 || frame.intersects(captureButton) { return true }
            if ["Tout", "Pro", "Perso"].contains(element.label), frame.minY < screen.minY + 260 { return true }
            if frame.minY < screen.minY + 130, element.elementType == .button || element.elementType == .staticText { return true }
        case .dynamicType:
            if frame.minY < screen.minY + 130, element.elementType == .button { return true }
            if ["Tout", "Pro", "Perso"].contains(element.label), frame.minY < screen.minY + 260 { return true }
        case .textClipped:
            if frame.minY < screen.minY + 130, element.elementType == .staticText { return true }
            if element.elementType == .searchField { return true }
        default:
            break
        }
        return false
    }

    @MainActor
    func testSummary() throws {
        let app = launch()
        try audit("Résumé", in: app, expecting: app.descendants(matching: .any)["ui.summaryHeader"])
    }

    @MainActor
    func testExpenses() throws {
        let app = launch(tab: "expenses")
        XCTAssertTrue(app.navigationBars["Dépenses"].waitForExistence(timeout: 10))
        // The list can open slightly scrolled (search field half collapsed), with its first
        // row in the bar's fading edge: bring it to rest at the top, search field shown.
        app.cells.firstMatch.swipeDown()
        try audit("Dépenses", in: app, expecting: app.searchFields.firstMatch)
    }

    @MainActor
    func testDetailAndForm() throws {
        let app = launch(route: "expense:Monoprix")
        let edit = app.buttons["ui.detailEdit"]
        try audit("Détail", in: app, expecting: edit)
        edit.tap()
        try audit("Formulaire", in: app, expecting: app.buttons["ui.formSave"])
    }

    @MainActor
    func testBudgets() throws {
        let app = launch(route: "budgets")
        XCTAssertTrue(app.navigationBars["Budgets"].waitForExistence(timeout: 10), "The budgets screen is open")
        try audit("Budgets", in: app, expecting: app.buttons["ui.budgetAdd"])
    }

    @MainActor
    func testSettings() throws {
        let app = launch(tab: "settings")
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 10))
        try audit("Réglages", in: app, expecting: app.descendants(matching: .any)["ui.settingsRecurring"])
    }
}
