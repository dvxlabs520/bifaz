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

/// Sample data for previews and the debug `-BifazSampleData YES` launch argument:
/// seven months of French expenses in both spaces, VAT at one or several rates,
/// expenses without a category, and three budgets (on track, near the limit, over).
enum SampleData {
    static func insert(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        try CategorySeeder.seedIfNeeded(in: context)
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        func category(_ key: String) -> ExpenseCategory? { categories.first { $0.seedKey == key } }
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let today = calendar.component(.day, from: now)
        /// Day `day` of the month `monthsAgo` months back, never after today.
        func date(_ monthsAgo: Int, _ day: Int) -> Date {
            let month = calendar.date(byAdding: .month, value: -monthsAgo, to: thisMonth) ?? thisMonth
            let clamped = monthsAgo == 0 ? min(day, today) : day
            return calendar.date(byAdding: .day, value: clamped - 1, to: month)?.addingTimeInterval(11 * 3600) ?? month
        }
        typealias Item = (amount: String, merchant: String, space: Space, key: String?, monthsAgo: Int, day: Int, rate: VATRate?)
        var items: [Item] = [
            // This month.
            ("87.00", "SNCF", .pro, "category.pro.transport", 0, 2, .intermediate),
            ("71.99", "Adobe", .pro, "category.pro.software", 0, 3, .standard),
            ("142.50", "Hôtel Mercure Lyon", .pro, "category.pro.lodging", 0, 6, .intermediate),
            ("48.60", "Brasserie Le Zinc", .pro, "category.pro.meals", 0, 6, .intermediate),
            ("19.99", "Free Mobile", .pro, "category.pro.phone", 0, 8, .standard),
            ("64.89", "TotalEnergies", .pro, "category.pro.car", 0, 10, .standard),
            ("12.00", "Parking Indigo", .pro, nil, 0, 10, .standard),
            ("23.40", "Monoprix", .personal, "category.personal.groceries", 0, 1, nil),
            ("96.30", "Carrefour", .personal, "category.personal.groceries", 0, 5, nil),
            ("54.12", "Franprix", .personal, "category.personal.groceries", 0, 9, nil),
            ("6.80", "Boulangerie Paul", .personal, "category.personal.restaurants", 0, 4, nil),
            ("68.00", "Le Petit Bouillon", .personal, "category.personal.restaurants", 0, 7, nil),
            ("38.90", "Pharmacie Lafayette", .personal, "category.personal.health", 0, 9, nil),
            ("29.99", "Fnac", .personal, nil, 0, 11, nil),
        ]
        // Earlier months: a steady base that varies a little.
        for monthsAgo in 1...6 {
            let k = Decimal(100 + (monthsAgo * 7) % 23) / 100
            func scaled(_ amount: String) -> String { "\((Decimal(string: amount)! * k).rounded(scale: 2))" }
            items += [
                (scaled("120.00"), "SNCF", .pro, "category.pro.transport", monthsAgo, 4, .intermediate),
                (scaled("71.99"), "Adobe", .pro, "category.pro.software", monthsAgo, 3, .standard),
                (scaled("19.99"), "Free Mobile", .pro, "category.pro.phone", monthsAgo, 8, .standard),
                (scaled("86.40"), "Restaurant Chez Marcel", .pro, "category.pro.meals", monthsAgo, 14, .intermediate),
                (scaled("210.00"), "Carrefour", .personal, "category.personal.groceries", monthsAgo, 6, nil),
                (scaled("75.00"), "Le Petit Bouillon", .personal, "category.personal.restaurants", monthsAgo, 18, nil),
                (scaled("45.00"), "Pharmacie Lafayette", .personal, "category.personal.health", monthsAgo, 21, nil),
            ]
        }
        for item in items {
            let draft = ExpenseDraft(
                amount: Decimal(string: item.amount),
                merchant: item.merchant,
                date: date(item.monthsAgo, item.day),
                space: item.space,
                category: item.key.flatMap(category),
                vatRate: item.rate
            )
            try ExpenseService.create(from: draft, in: context)
        }
        // A supermarket receipt with two printed rates (5,5 % food, 20 % the rest).
        var monoprix = ExpenseDraft(amount: Decimal(string: "27.55"), merchant: "Monoprix", date: date(0, 12),
                                    space: .pro, category: category("category.pro.office"))
        monoprix.setVAT(VATBreakdown.lines(fromPrinted: [
            PrintedVATLine(rate: VATRate.reduced.fraction, base: Decimal(string: "10.00"), vat: Decimal(string: "0.55")),
            PrintedVATLine(rate: VATRate.standard.fraction, base: Decimal(string: "14.17"), vat: Decimal(string: "2.83")),
        ], total: Decimal(string: "27.55")!))
        try ExpenseService.create(from: monoprix, in: context)
        if let pending = try context.fetch(FetchDescriptor<Expense>()).first(where: { $0.merchant == "SNCF" && $0.date >= thisMonth }) {
            pending.status = .receiptPending
        }

        // Phase 4: a client and a project on some Pro expenses, a dollar invoice and a monthly rule.
        let studio = try TagService.create("Studio Nord", kind: .client, in: context)
        let site = try TagService.create("Site vitrine", kind: .project, in: context)
        for expense in try context.fetch(FetchDescriptor<Expense>()) where expense.space == .pro
            && ["Hôtel Mercure Lyon", "Brasserie Le Zinc", "SNCF"].contains(expense.merchant) && expense.date >= thisMonth {
            var edit = ExpenseDraft(expense: expense)
            edit.client = studio
            edit.project = expense.merchant == "SNCF" ? nil : site
            try ExpenseService.update(expense, with: edit, in: context, saving: false)
        }
        var github = ExpenseDraft(amount: 48, merchant: "GitHub", date: date(0, 13), space: .pro, category: category("category.pro.software"))
        github.currencyCode = "USD"
        github.exchangeRate = ExchangeRateQuote(currencyCode: "USD", rate: Decimal(string: "1.1052")!, date: date(0, 13), source: .ecb)
        try ExpenseService.create(from: github, in: context, saving: false)
        if let office = category("category.pro.office") {
            let rent = ExpenseDraft(amount: 450, merchant: "Loyer bureau", space: .pro, category: office, vatRate: .standard)
            let start = calendar.date(byAdding: .month, value: -2, to: thisMonth).flatMap { calendar.date(byAdding: .day, value: 4, to: $0) } ?? now
            try RecurringService.create(.init(draft: rent, frequency: .monthly, startDate: start), in: context, now: now, calendar: calendar)
        }

        // Budgets for this month: transport on track, groceries near the limit, restaurants over.
        if let transport = category("category.pro.transport") { try BudgetService.setBudget(300, for: transport, in: context) }
        if let groceries = category("category.personal.groceries") { try BudgetService.setBudget(200, for: groceries, in: context) }
        if let restaurants = category("category.personal.restaurants") { try BudgetService.setBudget(70, for: restaurants, in: context) }
        try context.save()
    }

    /// `-BifazLargeSample YES`: 5,000 expenses over two years, to measure the Summary.
    static func insertLarge(into context: ModelContext, now: Date = .now) throws {
        try CategorySeeder.seedIfNeeded(in: context)
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        var generator = SystemRandomNumberGenerator()
        for index in 0..<5000 {
            let space: Space = index.isMultiple(of: 2) ? .pro : .personal
            let amount = Decimal(Int.random(in: 100...30_000, using: &generator)) / 100
            var draft = ExpenseDraft(
                amount: amount,
                merchant: "Commerce \(index % 97)",
                date: now.addingTimeInterval(-Double.random(in: 0..<(730 * 86_400), using: &generator)),
                space: space,
                category: categories.filter { $0.space == space }.randomElement(using: &generator)
            )
            if space == .pro { draft.vatRate = VATRate.allCases.randomElement(using: &generator) }
            let expense = Expense(amount: 0, space: space)
            context.insert(expense)
            try ExpenseService.update(expense, with: draft, in: context, saving: false)
        }
        try context.save()
    }
}
