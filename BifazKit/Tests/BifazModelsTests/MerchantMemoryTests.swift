import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("MerchantMemory")
struct MerchantMemoryTests {
    @Test("remember then suggestion, accent and case insensitive", arguments: ["Café Flore", "cafe flore", "CAFÉ   FLORE", " café flore "])
    func lookup(query: String) throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let category = ExpenseCategory(name: "Meals", space: .pro)
        context.insert(category)
        let expense = Expense(amount: 5, merchant: "Café Flore", space: .pro, category: category)
        context.insert(expense)
        MerchantMemory.remember(expense, in: context)
        try context.save()

        let rule = MerchantMemory.suggestion(for: query, in: context)
        #expect(rule?.merchantName == "Café Flore")
        #expect(rule?.space == .pro)
        #expect(rule?.category === category)
    }

    @Test("Unknown or empty merchant has no suggestion")
    func noSuggestion() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        #expect(MerchantMemory.suggestion(for: "Nobody", in: container.mainContext) == nil)
        #expect(MerchantMemory.suggestion(for: "  ", in: container.mainContext) == nil)
    }

    @Test("A second expense refreshes the single rule")
    func refresh() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let a = ExpenseCategory(name: "A", space: .personal), b = ExpenseCategory(name: "B", space: .pro)
        context.insert(a); context.insert(b)
        let first = Expense(amount: 5, merchant: "Amazon", space: .personal, category: a)
        let second = Expense(amount: 9, merchant: "AMAZON", space: .pro, category: b)
        context.insert(first); context.insert(second)
        MerchantMemory.remember(first, in: context)
        try context.save()
        MerchantMemory.remember(second, in: context)
        try context.save()

        let rules = try context.fetch(FetchDescriptor<MerchantRule>())
        #expect(rules.count == 1)
        #expect(rules.first?.merchantName == "AMAZON")
        #expect(rules.first?.space == .pro)
        #expect(rules.first?.category === b)
    }

    @Test("Empty merchant is ignored")
    func emptyIgnored() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let expense = Expense(amount: 5, merchant: "  ", space: .personal)
        context.insert(expense)
        MerchantMemory.remember(expense, in: context)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<MerchantRule>()).isEmpty)
    }

    private func seedRules(_ context: ModelContext) throws {
        let names = ["Carrefour", "Cafe Zoe", "Café Flore", "Monoprix"]
        for (index, name) in names.enumerated() {
            let rule = MerchantRule(merchantName: name, space: .personal)
            rule.updatedAt = Date(timeIntervalSince1970: Double(1000 * (index + 1)))
            context.insert(rule)
        }
        try context.save()
    }

    @Test("merchants(matching:) filters by prefix, most recent first")
    func prefixOrdering() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        try seedRules(container.mainContext)
        #expect(MerchantMemory.merchants(matching: "ca", in: container.mainContext) == ["Café Flore", "Cafe Zoe", "Carrefour"])
        #expect(MerchantMemory.merchants(matching: "CAFÉ", in: container.mainContext) == ["Café Flore", "Cafe Zoe"])
        #expect(MerchantMemory.merchants(matching: "zoe", in: container.mainContext).isEmpty)
    }

    @Test("merchants(matching:) honours the limit and ignores empty prefixes")
    func limitAndEmpty() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        try seedRules(container.mainContext)
        #expect(MerchantMemory.merchants(matching: "ca", limit: 2, in: container.mainContext) == ["Café Flore", "Cafe Zoe"])
        #expect(MerchantMemory.merchants(matching: "", in: container.mainContext).isEmpty)
        #expect(MerchantMemory.merchants(matching: "  ", in: container.mainContext).isEmpty)
    }
}
