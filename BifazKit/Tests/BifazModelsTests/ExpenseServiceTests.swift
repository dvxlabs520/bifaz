import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("ExpenseService")
struct ExpenseServiceTests {
    @Test("create stores the normalised draft")
    func create() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let category = ExpenseCategory(name: "Meals", space: .pro)
        context.insert(category)
        let date = parisDate(2026, 5, 2)
        let draft = ExpenseDraft(
            amount: decimal("110.004"), merchant: "  Chez   Paul ", date: date, space: .pro,
            category: category, vatRate: .intermediate, note: "  client lunch \n"
        )
        let expense = try ExpenseService.create(from: draft, in: context)

        #expect(expense.amount == decimal("110.00"))
        #expect(expense.amountInEUR == decimal("110.00"))
        #expect(expense.currencyCode == "EUR")
        #expect(expense.merchant == "Chez Paul")
        #expect(expense.note == "client lunch")
        #expect(expense.vatRate == decimal("0.10"))
        #expect(expense.vatAmount == decimal("10.00"))
        #expect(expense.space == .pro)
        #expect(expense.category === category)
        #expect(expense.date == date)
        #expect(try context.fetch(FetchDescriptor<Expense>()).count == 1)
    }

    @Test("create without VAT leaves VAT empty")
    func createWithoutVAT() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let expense = try ExpenseService.create(from: ExpenseDraft(amount: 5), in: container.mainContext)
        #expect(expense.vatRate == nil)
        #expect(expense.vatAmount == nil)
        #expect(expense.space == .personal)
    }

    @Test("create with an invalid draft throws and inserts nothing", arguments: [
        ("missing", ExpenseDraft.ValidationError.missingAmount),
        ("zero", .amountNotPositive),
        ("negative", .amountNotPositive),
        ("large", .amountTooLarge),
    ])
    func createInvalid(kind: String, expected: ExpenseDraft.ValidationError) throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var draft = ExpenseDraft(merchant: "Shop")
        switch kind {
        case "zero": draft.amount = 0
        case "negative": draft.amount = -3
        case "large": draft.amount = MoneyParser.maximum + 1
        default: break
        }
        #expect(throws: expected) { try ExpenseService.create(from: draft, in: context) }
        #expect(try context.fetch(FetchDescriptor<Expense>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MerchantRule>()).isEmpty)
    }

    @Test("create with a category from the other space throws")
    func createOtherSpace() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let category = ExpenseCategory(name: "Pro", space: .pro)
        context.insert(category)
        let draft = ExpenseDraft(amount: 5, space: .personal, category: category)
        #expect(throws: ExpenseDraft.ValidationError.categoryInOtherSpace) {
            try ExpenseService.create(from: draft, in: context)
        }
        #expect(try context.fetch(FetchDescriptor<Expense>()).isEmpty)
    }

    @Test("update changes the fields and bumps updatedAt")
    func update() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let expense = try ExpenseService.create(
            from: ExpenseDraft(amount: 10, merchant: "Old", space: .personal), in: context)
        expense.updatedAt = .distantPast
        let category = ExpenseCategory(name: "Software", space: .pro)
        context.insert(category)
        let date = parisDate(2026, 6, 1)

        try ExpenseService.update(expense, with: ExpenseDraft(
            amount: 120, merchant: " New  Co ", date: date, space: .pro,
            category: category, vatRate: .standard, note: " n "
        ), in: context)

        #expect(expense.amount == 120)
        #expect(expense.amountInEUR == 120)
        #expect(expense.merchant == "New Co")
        #expect(expense.date == date)
        #expect(expense.space == .pro)
        #expect(expense.category === category)
        #expect(expense.vatRate == decimal("0.20"))
        #expect(expense.vatAmount == 20)
        #expect(expense.note == "n")
        #expect(expense.updatedAt > .distantPast)
        #expect(try context.fetch(FetchDescriptor<Expense>()).count == 1)
    }

    @Test("update with an invalid draft throws and leaves the expense untouched")
    func updateInvalid() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let expense = try ExpenseService.create(from: ExpenseDraft(amount: 10, merchant: "Keep"), in: context)
        #expect(throws: ExpenseDraft.ValidationError.amountNotPositive) {
            try ExpenseService.update(expense, with: ExpenseDraft(amount: 0, merchant: "Changed"), in: context)
        }
        #expect(expense.amount == 10)
        #expect(expense.merchant == "Keep")
    }

    @Test("delete removes the expense and cascades to its receipt")
    func delete() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let expense = try ExpenseService.create(from: ExpenseDraft(amount: 10, merchant: "Shop"), in: context)
        let receipt = Receipt(fileName: "r.jpg")
        context.insert(receipt)
        expense.receipt = receipt
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Receipt>()).count == 1)

        try ExpenseService.delete(expense, in: context)
        #expect(try context.fetch(FetchDescriptor<Expense>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Receipt>()).isEmpty)
    }

    @Test("create and update record a merchant rule")
    func recordsRule() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let category = ExpenseCategory(name: "Meals", space: .pro)
        context.insert(category)
        let expense = try ExpenseService.create(
            from: ExpenseDraft(amount: 10, merchant: "Chez Paul", space: .pro, category: category), in: context)
        var rules = try context.fetch(FetchDescriptor<MerchantRule>())
        #expect(rules.count == 1)
        #expect(rules.first?.merchantName == "Chez Paul")
        #expect(rules.first?.space == .pro)
        #expect(rules.first?.category === category)

        try ExpenseService.update(expense, with: ExpenseDraft(amount: 10, merchant: "chez paul", space: .personal), in: context)
        rules = try context.fetch(FetchDescriptor<MerchantRule>())
        #expect(rules.count == 1)
        #expect(rules.first?.merchantName == "chez paul")
        #expect(rules.first?.space == .personal)
        #expect(rules.first?.category == nil)
    }

    @Test("An expense without merchant records no rule")
    func noMerchantNoRule() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        try ExpenseService.create(from: ExpenseDraft(amount: 10, merchant: "   "), in: container.mainContext)
        #expect(try container.mainContext.fetch(FetchDescriptor<MerchantRule>()).isEmpty)
    }
}
