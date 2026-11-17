import Foundation
import SwiftData

/// The categories Bifaz creates on first launch, per space.
///
/// `key` doubles as the String Catalog key of the name (the app localises it
/// at seeding time, so names are user data afterwards and can be renamed).
/// `iconName` is a `BifazIcon` raw value.
public struct DefaultCategory: Sendable, Hashable {
    public let key: String
    public let iconName: String
    public let space: Space

    public static let all: [DefaultCategory] = pro + personal

    public static let pro: [DefaultCategory] = [
        .init(key: "category.pro.transport", iconName: "transport", space: .pro),
        .init(key: "category.pro.car", iconName: "car", space: .pro),
        .init(key: "category.pro.meals", iconName: "meal", space: .pro),
        .init(key: "category.pro.lodging", iconName: "lodging", space: .pro),
        .init(key: "category.pro.equipment", iconName: "equipment", space: .pro),
        .init(key: "category.pro.software", iconName: "software", space: .pro),
        .init(key: "category.pro.phone", iconName: "phone", space: .pro),
        .init(key: "category.pro.services", iconName: "services", space: .pro),
        .init(key: "category.pro.training", iconName: "training", space: .pro),
        .init(key: "category.pro.office", iconName: "office", space: .pro),
        .init(key: "category.pro.bankFees", iconName: "bankFees", space: .pro),
        .init(key: "category.pro.other", iconName: "other", space: .pro),
    ]

    public static let personal: [DefaultCategory] = [
        .init(key: "category.personal.groceries", iconName: "groceries", space: .personal),
        .init(key: "category.personal.restaurants", iconName: "meal", space: .personal),
        .init(key: "category.personal.transport", iconName: "transport", space: .personal),
        .init(key: "category.personal.home", iconName: "furniture", space: .personal),
        .init(key: "category.personal.health", iconName: "health", space: .personal),
        .init(key: "category.personal.leisure", iconName: "leisure", space: .personal),
        .init(key: "category.personal.shopping", iconName: "shopping", space: .personal),
        .init(key: "category.personal.subscriptions", iconName: "subscriptions", space: .personal),
        .init(key: "category.personal.travel", iconName: "travel", space: .personal),
        .init(key: "category.personal.other", iconName: "other", space: .personal),
    ]
}

public enum CategorySeeder {
    /// Inserts the default categories into an empty store, so it is safe to call
    /// on every launch. Built-in categories are stored without a name (`name == ""`)
    /// and identified by `seedKey`: every device shows them in its current language
    /// (see `ExpenseCategory.displayName(localize:)`), until the user renames one.
    /// Returns how many were inserted.
    @discardableResult
    public static func seedIfNeeded(in context: ModelContext) throws -> Int {
        // Seed only into an empty store: once the user has categories, deleting
        // a default one must not bring it back on the next launch.
        guard try context.fetchCount(FetchDescriptor<ExpenseCategory>()) == 0 else { return 0 }
        for (space, defaults) in [(Space.pro, DefaultCategory.pro), (.personal, DefaultCategory.personal)] {
            for (index, item) in defaults.enumerated() {
                context.insert(ExpenseCategory(
                    name: "",
                    iconName: item.iconName,
                    space: space,
                    sortOrder: index,
                    seedKey: item.key
                ))
            }
        }
        try context.save()
        return DefaultCategory.all.count
    }

    /// One-time repair for stores created before names followed the language:
    /// a built-in category whose stored name is one of its default translations
    /// was never renamed, so its name is cleared to follow the language again.
    /// Idempotent. Returns how many were repaired.
    @discardableResult
    public static func adoptTranslatedDefaults(
        in context: ModelContext,
        knownNames: (String) -> Set<String>
    ) throws -> Int {
        let builtIn = try context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.seedKey != "" && $0.name != "" }))
        var repaired = 0
        for category in builtIn where knownNames(category.seedKey).contains(category.name) {
            category.name = ""
            repaired += 1
        }
        if repaired > 0 { try context.save() }
        return repaired
    }
}

public extension ExpenseCategory {
    /// The name to show: what the user typed, or, for a built-in category never
    /// renamed, its default name in the current language via `localize(seedKey)`.
    func displayName(localize: (String) -> String) -> String {
        if name.isEmpty, !seedKey.isEmpty { return localize(seedKey) }
        return name
    }

    /// Whether this built-in category still uses its translated default name.
    var usesDefaultName: Bool { name.isEmpty && !seedKey.isEmpty }
}
