import XCTest

/// End-to-end UI tests of the phase-1 flows on a fresh in-memory store
/// (`-BifazUITesting YES`), in English so system texts are predictable.
/// Every step checks the month total shown on Summary.
final class ExpenseFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAddingAnExpenseUpdatesTheMonthTotal() {
        let app = launch()
        XCTAssertTrue(waitForTotal("€0.00", in: app), "Fresh store shows a zero total")

        addExpense(amount: "12.50", merchant: "UITest Bakery", in: app)

        XCTAssertTrue(waitForTotal("€12.50", in: app), "The new expense is counted in the month total")
    }

    @MainActor
    func testEditingAndDeletingAnExpenseUpdatesTheMonthTotal() {
        let app = launch()
        addExpense(amount: "12.50", merchant: "UITest Bakery", in: app)
        XCTAssertTrue(waitForTotal("€12.50", in: app))

        // Edit: 12.50 → 20.00.
        openDetail(of: "UITest Bakery", in: app)
        app.buttons["ui.detailEdit"].tap()
        let amount = app.textFields["ui.formAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "20.00")
        app.buttons["ui.formSave"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "€20.00")).firstMatch.waitForExistence(timeout: 5),
                      "The detail shows the edited amount")
        let back = app.navigationBars.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons["ui.detailEdit"].waitForNonExistence(timeout: 5), "Back to the history")
        app.tabBars.buttons["Summary"].tap()
        XCTAssertTrue(waitForTotal("€20.00", in: app), "Editing updates the month total")

        // Delete with confirmation.
        openDetail(of: "UITest Bakery", in: app)
        app.buttons["ui.detailEdit"].tap()
        let delete = app.buttons["ui.formDelete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        var swipes = 0
        while !delete.isHittable, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        delete.tap()
        // The confirmation sheet exposes its button twice; tap the one on screen.
        let confirmations = app.buttons.matching(identifier: "ui.formDeleteConfirm")
        XCTAssertTrue(confirmations.firstMatch.waitForExistence(timeout: 5), "Deleting asks for confirmation")
        let confirm = confirmations.allElementsBoundByIndex.first { $0.isHittable } ?? confirmations.firstMatch
        confirm.tap()
        XCTAssertTrue(app.buttons["ui.formSave"].waitForNonExistence(timeout: 5), "The form closes after deleting")
        XCTAssertTrue(app.buttons["ui.detailEdit"].waitForNonExistence(timeout: 5), "The detail closes after deleting")

        app.tabBars.buttons["Summary"].tap()
        XCTAssertTrue(waitForTotal("€0.00", in: app), "Deleting removes the expense from the month total")
    }

    // MARK: - Helpers

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-BifazUITesting", "YES",
            "-BifazInitialTab", "summary",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func addExpense(amount: String, merchant: String, in app: XCUIApplication) {
        app.buttons["ui.captureButton"].tap()
        let amountField = app.textFields["ui.formAmount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "Quick add opens")
        amountField.tap()
        amountField.typeText(amount)
        let merchantField = app.textFields["ui.formMerchant"]
        merchantField.tap()
        merchantField.typeText(merchant)
        app.buttons["ui.formSave"].tap()
        XCTAssertTrue(app.buttons["ui.captureButton"].waitForExistence(timeout: 5), "The sheet closes after saving")
    }

    @MainActor
    private func openDetail(of merchant: String, in app: XCUIApplication) {
        app.tabBars.buttons["Expenses"].tap()
        // Rows of a List are exposed as cells or buttons depending on the OS version.
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND (elementType == %d OR elementType == %d)",
                                  merchant, XCUIElement.ElementType.cell.rawValue, XCUIElement.ElementType.button.rawValue))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The expense is in the history")
        row.tap()
        XCTAssertTrue(app.buttons["ui.detailEdit"].waitForExistence(timeout: 5), "The detail opens")
    }

    @MainActor
    private func waitForTotal(_ text: String, in app: XCUIApplication) -> Bool {
        let header = app.descendants(matching: .any)["ui.summaryHeader"]
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: header)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }
}
