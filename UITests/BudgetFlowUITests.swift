import XCTest

/// Phase 3: create a budget from the Summary, add expenses and watch its state
/// go from on track to near the limit (80 %) and over (100 %), with the in-app alert.
/// Fresh in-memory store (`-BifazUITesting YES`), in English.
final class BudgetFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBudgetStateFollowsTheExpenses() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-BifazUITesting", "YES",
            "-BifazInitialTab", "summary",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-spaceFilter", "personal",
        ]
        app.launch()

        // The Summary shows its sections once there is an expense.
        addExpense(amount: "5.00", category: nil, in: app)

        // A discreet invitation leads to the budget editor.
        let createFirst = app.buttons["ui.budgetCreateFirst"]
        scrollTo(createFirst, in: app)
        createFirst.tap()
        let groceries = app.buttons.matching(identifier: "ui.budgetCategory").matching(NSPredicate(format: "label == %@", "Groceries")).firstMatch
        XCTAssertTrue(groceries.waitForExistence(timeout: 5), "The editor lists the categories without a budget")
        groceries.tap()
        let amount = app.textFields["ui.budgetAmount"]
        amount.tap()
        amount.typeText("100")
        app.buttons["ui.budgetSave"].tap()
        XCTAssertTrue(app.buttons["ui.budgetSave"].waitForNonExistence(timeout: 5), "The editor closes after saving")

        let status = app.descendants(matching: .any).matching(identifier: "ui.budgetStatus").firstMatch
        scrollTo(status, in: app)
        XCTAssertTrue(wait(for: status, valueContains: "Within budget"), "A new budget with nothing spent is on track")

        // 85 € of 100 €: near the limit, with the in-app alert.
        addExpense(amount: "85.00", category: "Groceries", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["ui.budgetAlert"].waitForExistence(timeout: 5),
                      "Crossing 80 % shows the in-app alert")
        scrollTo(status, in: app)
        XCTAssertTrue(wait(for: status, valueContains: "Close to the limit"), "85 % is near the limit")

        // 105 € of 100 €: over.
        addExpense(amount: "20.00", category: "Groceries", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["ui.budgetAlert"].waitForExistence(timeout: 5),
                      "Crossing 100 % shows the in-app alert")
        scrollTo(status, in: app)
        XCTAssertTrue(wait(for: status, valueContains: "Over budget"), "105 % is over")
    }

    // MARK: - Helpers

    @MainActor
    private func addExpense(amount: String, category: String?, in app: XCUIApplication) {
        app.buttons["ui.captureButton"].tap()
        let manual = app.buttons["ui.captureManual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "The capture menu opens")
        manual.tap()
        let amountField = app.textFields["ui.formAmount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "Quick add opens")
        amountField.tap()
        amountField.typeText(amount)
        if let category {
            let chip = app.buttons[category].firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "The category is offered")
            chip.tap()
        }
        app.buttons["ui.formSave"].tap()
        XCTAssertTrue(app.buttons["ui.captureButton"].waitForExistence(timeout: 5), "The sheet closes after saving")
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !(element.exists && element.isHittable), swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists, "\(element) is on the Summary")
    }

    @MainActor
    private func wait(for element: XCUIElement, valueContains text: String) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }
}
