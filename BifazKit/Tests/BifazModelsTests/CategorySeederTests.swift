import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("CategorySeeder")
struct CategorySeederTests {
    private func localized(_ key: String) -> String { "L:" + key }

    @Test("Defaults are 12 Pro and 10 Personal with unique keys")
    func defaults() {
        #expect(DefaultCategory.pro.count == 12)
        #expect(DefaultCategory.personal.count == 10)
        #expect(DefaultCategory.all.count == 22)
        #expect(Set(DefaultCategory.all.map(\.key)).count == 22)
    }

    @Test("Seeds every default without a stored name, with space, order, key and icon")
    func seeds() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let inserted = try CategorySeeder.seedIfNeeded(in: context)
        #expect(inserted == 22)

        let stored = try context.fetch(FetchDescriptor<ExpenseCategory>())
        #expect(stored.count == 22)
        for (space, defaults) in [(Space.pro, DefaultCategory.pro), (.personal, DefaultCategory.personal)] {
            let inSpace = stored.filter { $0.space == space }.sorted { $0.sortOrder < $1.sortOrder }
            #expect(inSpace.count == defaults.count)
            for (index, (category, item)) in zip(inSpace, defaults).enumerated() {
                #expect(category.name.isEmpty)
                #expect(category.usesDefaultName)
                #expect(category.displayName(localize: localized) == "L:" + item.key)
                #expect(category.seedKey == item.key)
                #expect(category.iconName == item.iconName)
                #expect(category.sortOrder == index)
                #expect(category.space == item.space)
            }
        }
    }

    @Test("A second call inserts nothing")
    func idempotent() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)
        #expect(try CategorySeeder.seedIfNeeded(in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<ExpenseCategory>()).count == 22)
    }

    @Test("A store that already has a user category is not seeded")
    func nonEmptyStore() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        context.insert(ExpenseCategory(name: "Mine", space: .personal))
        try context.save()
        #expect(try CategorySeeder.seedIfNeeded(in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<ExpenseCategory>()).count == 1)
    }

    @Test("Deleting a default does not bring it back")
    func deletedStaysDeleted() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)
        let first = try #require(try context.fetch(FetchDescriptor<ExpenseCategory>()).first)
        context.delete(first)
        try context.save()
        #expect(try CategorySeeder.seedIfNeeded(in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<ExpenseCategory>()).count == 21)
    }

    @Test("Built-in names follow the language; renamed ones keep the user's text")
    func displayNameFollowsLanguage() throws {
        let builtIn = ExpenseCategory(name: "", space: .pro, seedKey: "category.pro.software")
        #expect(builtIn.displayName(localize: { _ in "Logiciels" }) == "Logiciels")
        #expect(builtIn.displayName(localize: { _ in "Software" }) == "Software")
        builtIn.name = "Abonnements SaaS"
        #expect(builtIn.displayName(localize: { _ in "Logiciels" }) == "Abonnements SaaS")
        #expect(!builtIn.usesDefaultName)

        let userCategory = ExpenseCategory(name: "Mine", space: .personal)
        #expect(userCategory.displayName(localize: { _ in "ignored" }) == "Mine")
    }

    @Test("Legacy stores: default names stored in any language go back to following the language")
    func adoptTranslatedDefaults() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let spanish = ExpenseCategory(name: "Supermercado", space: .personal, seedKey: "category.personal.groceries")
        let renamed = ExpenseCategory(name: "Courses bio", space: .personal, seedKey: "category.personal.groceries")
        let user = ExpenseCategory(name: "Supermercado", space: .personal)
        [spanish, renamed, user].forEach(context.insert)
        try context.save()

        let translations: (String) -> Set<String> = { _ in ["Groceries", "Supermercado", "Courses"] }
        #expect(try CategorySeeder.adoptTranslatedDefaults(in: context, knownNames: translations) == 1)
        #expect(spanish.name.isEmpty)
        #expect(renamed.name == "Courses bio")
        #expect(user.name == "Supermercado")
        // Idempotent.
        #expect(try CategorySeeder.adoptTranslatedDefaults(in: context, knownNames: translations) == 0)
    }

    @Test("Search matches the translated name of built-in categories")
    func searchUsesDisplayName() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let category = ExpenseCategory(name: "", space: .pro, seedKey: "category.pro.software")
        context.insert(category)
        var draft = ExpenseDraft(amount: 10, merchant: "Adobe", space: .pro, category: category)
        draft.note = ""
        try ExpenseService.create(from: draft, in: context)
        let filter = ExpenseFilter(searchText: "logiciel")
        #expect(try filter.fetch(in: context, categoryName: { $0.displayName(localize: { _ in "Logiciels" }) }).count == 1)
        #expect(try filter.fetch(in: context).isEmpty)
    }
}
