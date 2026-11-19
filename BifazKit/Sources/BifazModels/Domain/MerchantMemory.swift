import Foundation
import SwiftData

/// Remembers, per merchant, the space and category used last time, so the
/// next expense at the same merchant is prefilled (PLAN §4 "comercio conocido").
public enum MerchantMemory {
    /// Stores or refreshes the rule for the expense's merchant. Does not save.
    public static func remember(_ expense: Expense, in context: ModelContext) {
        let key = MerchantRule.key(for: expense.merchant)
        guard !key.isEmpty else { return }
        let rule: MerchantRule
        if let existing = Self.rule(forKey: key, in: context) {
            rule = existing
            rule.merchantName = expense.merchant
            rule.space = expense.space
            rule.category = expense.category
            rule.updatedAt = .now
        } else {
            rule = MerchantRule(merchantName: expense.merchant, space: expense.space, category: expense.category)
            context.insert(rule)
        }
        // Client and project are remembered from Pro expenses only (phase 4).
        if expense.space == .pro {
            rule.client = expense.client
            rule.project = expense.project
        }
    }

    /// The learned rule for a merchant name, if any.
    public static func suggestion(for merchant: String, in context: ModelContext) -> MerchantRule? {
        let key = MerchantRule.key(for: merchant)
        guard !key.isEmpty else { return nil }
        return rule(forKey: key, in: context)
    }

    /// Known merchant names starting with `prefix` (case- and accent-insensitive), most recent first.
    public static func merchants(matching prefix: String, limit: Int = 5, in context: ModelContext) -> [String] {
        let key = MerchantRule.key(for: prefix)
        guard !key.isEmpty else { return [] }
        var descriptor = FetchDescriptor<MerchantRule>(
            predicate: #Predicate { $0.merchantKey.starts(with: key) },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map(\.merchantName)
    }

    /// The most recently used merchant names (offered as chips before typing).
    public static func recentMerchants(limit: Int = 6, in context: ModelContext) -> [String] {
        var descriptor = FetchDescriptor<MerchantRule>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map(\.merchantName)
    }

    private static func rule(forKey key: String, in context: ModelContext) -> MerchantRule? {
        var descriptor = FetchDescriptor<MerchantRule>(predicate: #Predicate { $0.merchantKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
