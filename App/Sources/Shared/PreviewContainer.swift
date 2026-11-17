import Foundation
import SwiftData
import BifazModels

/// In-memory containers for SwiftUI previews.
enum PreviewContainer {
    static let empty: ModelContainer = make(seeded: false)

    /// Default categories plus a few French sample expenses.
    static let sample: ModelContainer = make(seeded: true)

    private static func make(seeded: Bool) -> ModelContainer {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            if seeded { try SampleData.insert(into: container.mainContext) }
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }
}

/// Sample data for previews and the debug `-BifazSampleData YES` launch argument.
enum SampleData {
    static func insert(into context: ModelContext) throws {
        try CategorySeeder.seedIfNeeded(in: context)
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        func category(_ key: String) -> ExpenseCategory? { categories.first { $0.seedKey == key } }
        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: .now) ?? .now }

        let items: [(String, String, Space, String, Int, VATRate?, ExpenseStatus)] = [
            ("87.00", "SNCF", .pro, "category.pro.transport", 1, .intermediate, .receiptPending),
            ("71.99", "Adobe", .pro, "category.pro.software", 3, .standard, .confirmed),
            ("23.40", "Monoprix", .personal, "category.personal.groceries", 4, nil, .confirmed),
            ("6.80", "Boulangerie Paul", .personal, "category.personal.restaurants", 5, nil, .confirmed),
            ("142.50", "Hôtel Mercure Lyon", .pro, "category.pro.lodging", 9, .intermediate, .confirmed),
            ("38.90", "Pharmacie Lafayette", .personal, "category.personal.health", 12, nil, .confirmed),
            ("19.99", "Free Mobile", .pro, "category.pro.phone", 33, .standard, .confirmed),
            ("64.20", "Carrefour", .personal, "category.personal.groceries", 36, nil, .confirmed),
        ]
        for (amount, merchant, space, key, days, rate, status) in items {
            var draft = ExpenseDraft(
                amount: Decimal(string: amount),
                merchant: merchant,
                date: daysAgo(days),
                space: space,
                category: category(key),
                vatRate: rate
            )
            draft.note = ""
            let expense = try ExpenseService.create(from: draft, in: context)
            expense.status = status
        }
        try context.save()
    }
}
