import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("Relationships and delete rules")
struct RelationshipTests {
    @Test("Expense and category are inverses")
    func expenseCategory() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let category = ExpenseCategory(name: "Food", space: .personal)
        let expense = Expense(amount: 5, space: .personal)
        context.insert(category); context.insert(expense)
        expense.category = category
        try context.save()
        #expect(category.expenses?.contains { $0 === expense } == true)
    }

    @Test("Expense and tags are many-to-many")
    func expenseTags() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let a = Tag(name: "A", kind: .client), b = Tag(name: "B", kind: .project)
        let e1 = Expense(amount: 1, space: .pro), e2 = Expense(amount: 2, space: .pro)
        [a, b].forEach { context.insert($0) }
        [e1, e2].forEach { context.insert($0) }
        e1.tags = [a, b]
        e2.tags = [a]
        try context.save()
        #expect(a.expenses?.count == 2)
        #expect(b.expenses?.count == 1)
        #expect(e1.tags?.count == 2)
        #expect(b.expenses?.first === e1)
    }

    @Test("Expense and receipt are inverses")
    func expenseReceipt() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let expense = Expense(amount: 1, space: .pro)
        let receipt = Receipt()
        context.insert(expense); context.insert(receipt)
        expense.receipt = receipt
        try context.save()
        #expect(receipt.expense === expense)
    }

    @Test("Expense and session are inverses")
    func expenseSession() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let session = ExpenseSession(name: "S", space: .pro)
        let expense = Expense(amount: 1, space: .pro)
        context.insert(session); context.insert(expense)
        expense.session = session
        try context.save()
        #expect(session.expenses?.contains { $0 === expense } == true)
    }

    @Test("Recurring rule tracks its generated expenses")
    func recurringExpenses() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let rule = RecurringRule(amount: 10, space: .personal, frequency: .monthly, nextDate: .now)
        let expense = Expense(amount: 10, space: .personal, source: .recurring)
        context.insert(rule); context.insert(expense)
        expense.recurringRule = rule
        try context.save()
        #expect(rule.generatedExpenses?.contains { $0 === expense } == true)
    }

    @Test("Recurring rule and tags are inverses")
    func recurringTags() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let rule = RecurringRule(amount: 10, space: .pro, frequency: .weekly, nextDate: .now)
        let tag = Tag(name: "T", kind: .client)
        context.insert(rule); context.insert(tag)
        rule.tags = [tag]
        try context.save()
        #expect(tag.recurringRules?.contains { $0 === rule } == true)
    }

    @Test("Recurring rule and category are inverses")
    func recurringCategory() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let category = ExpenseCategory(name: "C", space: .pro)
        let rule = RecurringRule(amount: 10, space: .pro, category: category, frequency: .weekly, nextDate: .now)
        context.insert(category); context.insert(rule)
        try context.save()
        #expect(category.recurringRules?.contains { $0 === rule } == true)
    }

    @Test("Budget and category are inverses")
    func budgetCategory() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let category = ExpenseCategory(name: "C", space: .personal)
        let budget = Budget(category: category, monthlyAmount: 100)
        context.insert(category); context.insert(budget)
        try context.save()
        #expect(category.budgets?.contains { $0 === budget } == true)
    }

    @Test("Tag and session are inverses")
    func tagSession() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let tag = Tag(name: "Client", kind: .client)
        let session = ExpenseSession(name: "S", space: .pro, tag: tag)
        context.insert(tag); context.insert(session)
        try context.save()
        #expect(tag.sessions?.contains { $0 === session } == true)
        #expect(session.tag === tag)
    }

    @Test("Merchant rule and category are inverses")
    func merchantCategory() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let category = ExpenseCategory(name: "C", space: .personal)
        let rule = MerchantRule(merchantName: "Shop", space: .personal, category: category)
        context.insert(category); context.insert(rule)
        try context.save()
        #expect(category.merchantRules?.contains { $0 === rule } == true)
    }

    @Test("Deleting an expense cascades to its receipt")
    func deleteExpenseCascadesReceipt() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let expense = Expense(amount: 1, space: .pro)
        context.insert(expense)
        expense.receipt = Receipt()
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Receipt>()) == 1)
        context.delete(expense)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Receipt>()) == 0)
    }

    @Test("Deleting a category nullifies expenses and cascades to budgets")
    func deleteCategory() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let category = ExpenseCategory(name: "C", space: .personal)
        let expense = Expense(amount: 1, space: .personal)
        let budget = Budget(category: category, monthlyAmount: 50)
        context.insert(category); context.insert(expense); context.insert(budget)
        expense.category = category
        try context.save()
        context.delete(category)
        try context.save()
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        #expect(expenses.count == 1)
        #expect(expenses.first?.category == nil)
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 0)
    }

    @Test("Deleting a tag keeps the expenses")
    func deleteTag() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let tag = Tag(name: "T", kind: .client)
        let expense = Expense(amount: 1, space: .pro)
        context.insert(tag); context.insert(expense)
        expense.tags = [tag]
        try context.save()
        context.delete(tag)
        try context.save()
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        #expect(expenses.count == 1)
        #expect(expenses.first?.tags?.isEmpty ?? true)
    }
}
