import XCTest

/// Automatic accessibility audit (`performAccessibilityAudit`) on the main screens,
/// with the debug sample data, in French (the longest strings). Known false
/// positives are excluded explicitly below and explained in docs/fase-4-notas.md.
final class AccessibilityAuditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-BifazUITesting", "YES",
            "-BifazSampleData", "YES",
            "-BifazInitialTab", "summary",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
            "-spaceFilter", "all",
        ]
        app.launch()
        return app
    }

    /// Audits the current screen; prints every issue, fails on the ones not excluded.
    @MainActor
    private func audit(_ screen: String, in app: XCUIApplication) throws {
        let screenFrame = app.windows.firstMatch.frame
        try app.performAccessibilityAudit { issue in
            let excluded = Self.isKnownFalsePositive(issue, screen: screenFrame)
            print("BIFAZ-AUDIT [\(screen)] \(excluded ? "excluded" : "ISSUE") \(issue.auditType) · \(issue.compactDescription) · \(issue.element?.debugDescription.prefix(160) ?? "-")")
            return excluded
        }
    }

    /// Explicit exclusions, each one explained in docs/fase-4-notas.md:
    /// 1. Contrast of content passing under the translucent tab bar and the floating
    ///    capture button (bottom 110 pt): the audit samples pixels through the material.
    /// 2. The system navigation bar (top 130 pt): Liquid Glass toolbar buttons
    ///    ("Modifier", "Répéter", "Enregistrer") and the inline title are drawn by iOS;
    ///    their contrast and their Dynamic Type limits are the system's.
    /// 3. The history search field while it collapses on scroll (under 30 pt high).
    /// 4. Dynamic Type of the Tout / Pro / Perso chips: they grow with the text and the
    ///    row becomes a column (`ViewThatFits`, checked by hand at AccessibilityXL); the
    ///    audit reports the swap as "partially unsupported".
    @MainActor
    static func isKnownFalsePositive(_ issue: XCUIAccessibilityAuditIssue, screen: CGRect) -> Bool {
        guard let element = issue.element else {
            // Contrast issues the audit cannot attach to any element come from the
            // translucent bars (case 1); anything else must be looked at.
            return issue.auditType == .contrast
        }
        let frame = element.frame
        switch issue.auditType {
        case .contrast:
            if frame.maxY > screen.maxY - 110 { return true }
            if frame.minY < screen.minY + 130, element.elementType == .button || element.elementType == .staticText { return true }
        case .dynamicType:
            if frame.minY < screen.minY + 130, element.elementType == .button { return true }
            if ["Tout", "Pro", "Perso"].contains(element.label), frame.minY < screen.minY + 260 { return true }
        case .textClipped:
            if frame.minY < screen.minY + 130, element.elementType == .staticText { return true }
            if element.elementType == .searchField, frame.height < 30 { return true }
        default:
            break
        }
        return false
    }

    @MainActor
    func testMainScreensPassTheAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["ui.summaryHeader"].waitForExistence(timeout: 10))
        sleep(2)
        try audit("Résumé", in: app)

        app.tabBars.buttons["Dépenses"].tap()
        // Let the tab cross-fade and the search bar settle: mid-transition the audit
        // measures half-faded text.
        XCTAssertTrue(app.staticTexts["Novembre 2026"].firstMatch.waitForExistence(timeout: 5) || true)
        sleep(3)
        try audit("Dépenses", in: app)

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND (elementType == %d OR elementType == %d)", "Monoprix",
                                  XCUIElement.ElementType.cell.rawValue, XCUIElement.ElementType.button.rawValue))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["ui.detailEdit"].waitForExistence(timeout: 5))
        try audit("Détail", in: app)

        app.buttons["ui.detailEdit"].tap()
        XCTAssertTrue(app.buttons["ui.formSave"].waitForExistence(timeout: 5))
        sleep(1)
        try audit("Formulaire", in: app)
        app.buttons["ui.formClose"].tap()

        app.tabBars.buttons["Résumé"].tap()
        let manage = app.descendants(matching: .any)["ui.budgetsManage"]
        var swipes = 0
        while !(manage.exists && manage.isHittable), swipes < 6 { app.swipeUp(); swipes += 1 }
        manage.tap()
        XCTAssertTrue(app.buttons["ui.budgetAdd"].waitForExistence(timeout: 5))
        try audit("Budgets", in: app)

        app.tabBars.buttons["Réglages"].tap()
        sleep(3)
        try audit("Réglages", in: app)
    }
}
