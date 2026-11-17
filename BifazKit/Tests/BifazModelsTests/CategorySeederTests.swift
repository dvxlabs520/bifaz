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

    @Test("Seeds every default with name, space, order, key and icon")
    func seeds() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let inserted = try CategorySeeder.seedIfNeeded(in: context, localizedName: localized)
        #expect(inserted == 22)

        let stored = try context.fetch(FetchDescriptor<ExpenseCategory>())
        #expect(stored.count == 22)
        for (space, defaults) in [(Space.pro, DefaultCategory.pro), (.personal, DefaultCategory.personal)] {
            let inSpace = stored.filter { $0.space == space }.sorted { $0.sortOrder < $1.sortOrder }
            #expect(inSpace.count == defaults.count)
            for (index, (category, item)) in zip(inSpace, defaults).enumerated() {
                #expect(category.name == "L:" + item.key)
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
        try CategorySeeder.seedIfNeeded(in: context, localizedName: localized)
        #expect(try CategorySeeder.seedIfNeeded(in: context, localizedName: localized) == 0)
        #expect(try context.fetch(FetchDescriptor<ExpenseCategory>()).count == 22)
    }

    @Test("A store that already has a user category is not seeded")
    func nonEmptyStore() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        context.insert(ExpenseCategory(name: "Mine", space: .personal))
        try context.save()
        #expect(try CategorySeeder.seedIfNeeded(in: context, localizedName: localized) == 0)
        #expect(try context.fetch(FetchDescriptor<ExpenseCategory>()).count == 1)
    }

    @Test("Deleting a default does not bring it back")
    func deletedStaysDeleted() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context, localizedName: localized)
        let first = try #require(try context.fetch(FetchDescriptor<ExpenseCategory>()).first)
        context.delete(first)
        try context.save()
        #expect(try CategorySeeder.seedIfNeeded(in: context, localizedName: localized) == 0)
        #expect(try context.fetch(FetchDescriptor<ExpenseCategory>()).count == 21)
    }
}
