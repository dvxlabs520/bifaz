import XCTest

/// Phase 4: a USD expense with a typed rate counts in euros on the Summary, and
/// a monthly rule generates its expense. Fresh in-memory store, English, no network
/// (`-BifazUITesting YES` turns the ECB download off).
final class MultiCurrencyAndRecurringUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-BifazUITesting", "YES",
            "-BifazInitialTab", "summary",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-spaceFilter", "personal",
        ]
        app.launch()
        return app
    }

    @MainActor
    func testDollarExpenseWithTypedRateCountsInEuros() {
        let app = launch()
        app.buttons["ui.captureButton"].tap()
        let manual = app.buttons["ui.captureManual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()

        let amount = app.textFields["ui.formAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("48")
        app.buttons["ui.formCurrency"].tap()
        let dollar = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "(USD)")).firstMatch
        XCTAssertTrue(dollar.waitForExistence(timeout: 5), "The ECB currencies are offered")
        dollar.tap()

        // Offline and nothing stored: the rate is asked for.
        let rate = app.textFields["ui.formRate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5), "Without a stored rate, the form asks for one")
        rate.tap()
        rate.typeText("1.2")
        let euros = app.staticTexts["ui.formEuros"]
        XCTAssertTrue(euros.waitForExistence(timeout: 5))
        let converted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "40.00"), object: euros)
        XCTAssertEqual(XCTWaiter().wait(for: [converted], timeout: 5), .completed, "48 USD at 1.2 is €40.00")
        app.buttons["ui.formSave"].tap()
        XCTAssertTrue(app.buttons["ui.captureButton"].waitForExistence(timeout: 5), "The form closes")

        XCTAssertTrue(waitForTotal("€40.00", in: app), "The Summary counts the euro amount")
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "$48.00")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The original amount is shown too")
    }

    @MainActor
    func testMonthlyRuleGeneratesItsExpense() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        let recurring = app.descendants(matching: .any)["ui.settingsRecurring"]
        XCTAssertTrue(recurring.waitForExistence(timeout: 5))
        recurring.tap()
        let add = app.buttons["ui.ruleAdd"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let amount = app.textFields["ui.ruleAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("9.99")
        let merchant = app.textFields["ui.ruleMerchant"]
        merchant.tap()
        merchant.typeText("Streamly")
        let monthly = app.buttons["ui.ruleFrequency.monthly"]
        if monthly.exists { monthly.tap() }
        app.buttons["ui.ruleSave"].tap()
        XCTAssertTrue(app.buttons["ui.ruleSave"].waitForNonExistence(timeout: 5), "The editor closes")
        XCTAssertTrue(app.descendants(matching: .any)["ui.ruleRow"].waitForExistence(timeout: 5), "The rule is listed")

        // Starting today, its first expense is already there.
        app.tabBars.buttons["Expenses"].tap()
        let generated = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Streamly")).firstMatch
        XCTAssertTrue(generated.waitForExistence(timeout: 5), "The rule generated today's expense")
        app.tabBars.buttons["Summary"].tap()
        XCTAssertTrue(waitForTotal("€9.99", in: app))
    }

    /// v2: the "Repeat" chip of a new expense saves it and creates a monthly rule
    /// starting next month (so today counts once).
    @MainActor
    func testRepeatChipCreatesAMonthlyRule() {
        let app = launch()
        app.buttons["ui.captureButton"].tap()
        let manual = app.buttons["ui.captureManual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()
        let amount = app.textFields["ui.formAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("15.00")
        app.buttons["ui.sentence.merchant"].tap()
        let merchant = app.textFields["ui.formMerchant"]
        XCTAssertTrue(merchant.waitForExistence(timeout: 5))
        merchant.tap()
        merchant.typeText("Gym Club")
        app.buttons["ui.chip.repeat"].tap()
        let monthly = app.buttons["ui.repeat.monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5), "The repeat chip offers frequencies")
        monthly.tap()
        app.buttons["ui.formSave"].tap()
        XCTAssertTrue(app.buttons["ui.captureButton"].waitForExistence(timeout: 5), "The form closes")
        XCTAssertTrue(waitForTotal("€15.00", in: app), "Today's expense counts once")

        app.tabBars.buttons["Settings"].tap()
        let recurring = app.descendants(matching: .any)["ui.settingsRecurring"]
        XCTAssertTrue(recurring.waitForExistence(timeout: 5))
        recurring.tap()
        let row = app.descendants(matching: .any).matching(identifier: "ui.ruleRow")
            .matching(NSPredicate(format: "label CONTAINS %@", "Gym Club")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The rule is listed")
    }

    /// v2: "Repeat" is for euros; moving to a foreign currency drops the choice
    /// (the chip hides), so coming back to euros shows it unset, not silently kept.
    @MainActor
    func testForeignCurrencyClearsRepeat() {
        let app = launch()
        app.buttons["ui.captureButton"].tap()
        let manual = app.buttons["ui.captureManual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()
        let amount = app.textFields["ui.formAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("20.00")
        let repeatChip = app.buttons["ui.chip.repeat"]
        repeatChip.tap()
        let monthly = app.buttons["ui.repeat.monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        monthly.tap()
        XCTAssertTrue(repeatChip.label.contains("Monthly"), "The chip shows the choice: \(repeatChip.label)")

        app.buttons["ui.chip.currency"].tap()
        app.buttons["ui.formCurrency"].tap()
        let dollar = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "(USD)")).firstMatch
        XCTAssertTrue(dollar.waitForExistence(timeout: 5))
        dollar.tap()
        XCTAssertTrue(repeatChip.waitForNonExistence(timeout: 5), "No repeat for a foreign amount")

        app.buttons["ui.formCurrency"].tap()
        let euro = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "(EUR)")).firstMatch
        XCTAssertTrue(euro.waitForExistence(timeout: 5))
        euro.tap()
        XCTAssertTrue(repeatChip.waitForExistence(timeout: 5), "Back in euros, the chip is back")
        XCTAssertFalse(repeatChip.label.contains("Monthly"), "…unset: \(repeatChip.label)")
    }

    @MainActor
    private func waitForTotal(_ text: String, in app: XCUIApplication) -> Bool {
        let header = app.descendants(matching: .any)["ui.summaryHeader"]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: header)
        return XCTWaiter().wait(for: [expectation], timeout: 8) == .completed
    }
}
