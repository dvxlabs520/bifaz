import Foundation
import SwiftData

/// Remembers, per merchant, the space and category used last time, so the
/// next expense at the same merchant is prefilled (PLAN §4 "comercio conocido").
public enum MerchantMemory {
    /// Stores or refreshes the rule for the expense's merchant. Does not save.
    public static func remember(_ expense: Expense, in context: ModelContext) {
        let key = MerchantRule.key(for: expense.merchant)
        guard !key.isEmpty else { return }
        if let rule = rule(forKey: key, in: context) {
            rule.merchantName = expense.merchant
            rule.space = expense.space
            rule.category = expense.category
            rule.updatedAt = .now
        } else {
            context.insert(MerchantRule(merchantName: expense.merchant, space: expense.space, category: expense.category))
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

    private static func rule(forKey key: String, in context: ModelContext) -> MerchantRule? {
        var descriptor = FetchDescriptor<MerchantRule>(predicate: #Predicate { $0.merchantKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
