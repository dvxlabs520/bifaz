import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("ExpenseDraft")
struct ExpenseDraftTests {
    @Test("Validation: missing amount")
    func missing() {
        #expect(ExpenseDraft().validate() == .missingAmount)
        #expect(!ExpenseDraft().isValid)
    }

    @Test("Validation: amount not positive", arguments: ["0", "-1", "-0.01"])
    func notPositive(amount: String) {
        #expect(ExpenseDraft(amount: decimal(amount)).validate() == .amountNotPositive)
    }

    @Test("Validation: amount too large")
    func tooLarge() {
        #expect(ExpenseDraft(amount: MoneyParser.maximum + decimal("0.01")).validate() == .amountTooLarge)
        #expect(ExpenseDraft(amount: MoneyParser.maximum).validate() == nil)
    }

    @Test("Validation: category from the other space")
    func otherSpace() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let proCategory = ExpenseCategory(name: "Pro", space: .pro)
        container.mainContext.insert(proCategory)
        #expect(ExpenseDraft(amount: 5, space: .personal, category: proCategory).validate() == .categoryInOtherSpace)
        #expect(ExpenseDraft(amount: 5, space: .pro, category: proCategory).validate() == nil)
    }

    @Test("Validation: valid draft without category")
    func valid() {
        let draft = ExpenseDraft(amount: decimal("12.50"))
        #expect(draft.validate() == nil)
        #expect(draft.isValid)
    }

    @Test("Amount error wins over category error")
    func firstErrorWins() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let category = ExpenseCategory(name: "Pro", space: .pro)
        container.mainContext.insert(category)
        #expect(ExpenseDraft(amount: nil, space: .personal, category: category).validate() == .missingAmount)
    }

    @Test("normalizedMerchant trims and collapses whitespace", arguments: [
        ("  Café   de  Flore ", "Café de Flore"),
        ("SNCF", "SNCF"),
        ("a\t\nb", "a b"),
        ("   ", ""),
        ("", ""),
    ])
    func merchant(input: String, expected: String) {
        #expect(ExpenseDraft(merchant: input).normalizedMerchant == expected)
    }

    @Test("vatAmount needs both amount and rate")
    func vat() {
        #expect(ExpenseDraft(amount: 120, vatRate: .standard).vatAmount == 20)
        #expect(ExpenseDraft(amount: 110, vatRate: .intermediate).vatAmount == 10)
        #expect(ExpenseDraft(amount: 120, vatRate: nil).vatAmount == nil)
        #expect(ExpenseDraft(amount: nil, vatRate: .standard).vatAmount == nil)
        #expect(ExpenseDraft(amount: 120, vatRate: .zero).vatAmount == 0)
    }

    @Test("init(expense:) round-trips the stored values")
    func roundTrip() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let category = ExpenseCategory(name: "Meals", space: .pro)
        container.mainContext.insert(category)
        let date = parisDate(2026, 3, 14)
        let expense = Expense(
            amount: decimal("42.80"), date: date, merchant: "Chez Paul", space: .pro,
            category: category, vatRate: decimal("0.10"), note: "Lunch"
        )
        container.mainContext.insert(expense)
        let draft = ExpenseDraft(expense: expense)
        #expect(draft.amount == decimal("42.80"))
        #expect(draft.merchant == "Chez Paul")
        #expect(draft.date == date)
        #expect(draft.space == .pro)
        #expect(draft.category === category)
        #expect(draft.vatRate == .intermediate)
        #expect(draft.note == "Lunch")
        #expect(draft.isValid)
    }

    @Test("init(expense:) drops an unknown VAT fraction")
    func unknownVAT() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let expense = Expense(amount: 10, space: .personal, vatRate: decimal("0.19"))
        container.mainContext.insert(expense)
        #expect(ExpenseDraft(expense: expense).vatRate == nil)
    }
}
