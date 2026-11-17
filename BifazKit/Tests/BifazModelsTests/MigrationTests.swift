import Foundation
import SwiftData
import Testing
@testable import BifazModels

/// Opens a real on-disk v1 store with data in the current (v2) app container.
@MainActor
@Suite("Migrations v1 → v3 and v2 → v3", .serialized)
struct MigrationTests {
    struct Snapshot: Equatable {
        var id: UUID
        var amount: Decimal
        var amountInEUR: Decimal
        var currencyCode: String
        var date: Date
        var merchant: String
        var space: String
        var vatRate: Decimal?
        var vatAmount: Decimal?
        var note: String
        var source: String
        var status: String
        var category: String?
        var receiptFile: String?
        var tags: [String]
    }

    static func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "bifaz-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes a v1 store and returns what it holds.
    static func writeV1Store(at url: URL) throws -> [Snapshot] {
        let schema = Schema(versionedSchema: BifazSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let context = ModelContext(container)
        typealias V1 = BifazSchemaV1

        let meals = V1.ExpenseCategory(name: "Repas", iconName: "meal", space: .pro, seedKey: "category.pro.meals")
        let groceries = V1.ExpenseCategory(name: "Courses", iconName: "groceries", space: .personal, seedKey: "category.personal.groceries")
        context.insert(meals)
        context.insert(groceries)
        context.insert(V1.Budget(category: groceries, monthlyAmount: 400))
        let client = V1.Tag(name: "Client A", kind: .client)
        context.insert(client)
        context.insert(V1.MerchantRule(merchantName: "Monoprix", space: .personal, category: groceries))

        let date = Date(timeIntervalSince1970: 1_762_000_000)
        let expenses = [
            // Single rate, as v1 saved it: rate and computed VAT.
            V1.Expense(amount: decimal("23.40"), date: date, merchant: "Le Zinc", space: .pro, category: meals,
                       vatRate: decimal("0.10"), vatAmount: decimal("2.13"), note: "Déjeuner client", source: .scanner),
            // Several rates on the receipt: main rate and the printed total VAT.
            V1.Expense(amount: decimal("16.55"), date: date.addingTimeInterval(3600), merchant: "Monoprix", space: .pro,
                       vatRate: decimal("0.055"), vatAmount: decimal("1.55"), source: .scanner),
            // 0 %.
            V1.Expense(amount: decimal("8.00"), date: date, merchant: "Journal", space: .pro, vatRate: 0, vatAmount: 0),
            // No VAT.
            V1.Expense(amount: decimal("54.12"), date: date, merchant: "Monoprix", space: .personal, category: groceries),
            V1.Expense(amount: decimal("0.01"), date: date, merchant: "", space: .personal, status: .needsReview),
            V1.Expense(amount: decimal("9999.99"), date: date, merchant: "Fnac", space: .pro, vatRate: decimal("0.20"),
                       vatAmount: decimal("1666.67"), status: .receiptPending),
        ]
        for expense in expenses { context.insert(expense) }
        expenses[0].tags = [client]
        let receipt = V1.Receipt(fileName: "abc.jpg", thumbnailFileName: "abc-thumb.jpg", recognizedText: "LE ZINC")
        context.insert(receipt)
        expenses[0].receipt = receipt
        try context.save()

        return expenses.map { e in
            Snapshot(id: e.id, amount: e.amount, amountInEUR: e.amountInEUR, currencyCode: e.currencyCode, date: e.date,
                     merchant: e.merchant, space: e.spaceRawValue, vatRate: e.vatRate, vatAmount: e.vatAmount,
                     note: e.note, source: e.sourceRawValue, status: e.statusRawValue, category: e.category?.seedKey,
                     receiptFile: e.receipt?.fileName, tags: (e.tags ?? []).map(\.name))
        }
    }

    @Test("A v1 store with data opens in v2 with nothing lost and no amount changed")
    func migratesWithoutLoss() throws {
        let directory = try Self.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Bifaz.store")
        let before = try Self.writeV1Store(at: url)

        let container = try BifazStore.makeContainer(at: url)
        let context = container.mainContext
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let after = expenses.map { e in
            Snapshot(id: e.id, amount: e.amount, amountInEUR: e.amountInEUR, currencyCode: e.currencyCode, date: e.date,
                     merchant: e.merchant, space: e.spaceRawValue, vatRate: e.vatRate, vatAmount: e.vatAmount,
                     note: e.note, source: e.sourceRawValue, status: e.statusRawValue, category: e.category?.seedKey,
                     receiptFile: e.receipt?.fileName, tags: (e.tags ?? []).map(\.name))
        }
        #expect(after.sorted { $0.id.uuidString < $1.id.uuidString } == before.sorted { $0.id.uuidString < $1.id.uuidString })

        // Other entities survive with their links.
        #expect(try context.fetchCount(FetchDescriptor<ExpenseCategory>()) == 2)
        let budget = try #require(try context.fetch(FetchDescriptor<Budget>()).first)
        #expect(budget.monthlyAmount == 400 && budget.category?.seedKey == "category.personal.groceries")
        #expect(try context.fetch(FetchDescriptor<MerchantRule>()).first?.category?.seedKey == "category.personal.groceries")
        #expect(try context.fetchCount(FetchDescriptor<Receipt>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Tag>()) == 1)

        // VAT lines: one per expense with VAT; they add up to the amount and to the stored VAT.
        let byMerchant = Dictionary(grouping: expenses, by: \.merchant)
        for expense in expenses {
            let lines = expense.sortedVATLines.map(VATPart.init)
            if expense.vatAmount == nil {
                #expect(lines.isEmpty, "\(expense.merchant)")
            } else {
                #expect(lines.count == 1, "\(expense.merchant)")
                #expect(VATBreakdown.isConsistent(lines, amount: expense.amount), "\(expense.merchant)")
                #expect(lines.reduce(0) { $0 + $1.vat } == expense.vatAmount)
            }
        }
        #expect(byMerchant["Le Zinc"]?.first?.sortedVATLines.first?.rate == decimal("0.10"))
        #expect(byMerchant["Journal"]?.first?.sortedVATLines.first?.rate == 0)
        #expect(byMerchant["Fnac"]?.first?.sortedVATLines.first?.vat == decimal("1666.67"))
        // The several-rate receipt keeps its printed VAT, without inventing a split.
        let monoprixPro = try #require(byMerchant["Monoprix"]?.first { $0.space == .pro })
        #expect(monoprixPro.sortedVATLines.map(VATPart.init)
            == [VATPart(rate: nil, base: decimal("15.00"), vat: decimal("1.55"), total: decimal("16.55"))])

        // The migrated store keeps working: an edit that does not touch VAT keeps the line.
        var draft = ExpenseDraft(expense: monoprixPro)
        draft.note = "Fournitures"
        try ExpenseService.update(monoprixPro, with: draft, in: context)
        #expect(monoprixPro.sortedVATLines.count == 1 && monoprixPro.sortedVATLines.first?.rate == nil)
        #expect(monoprixPro.vatAmount == decimal("1.55"))
    }

    @Test("Opening a migrated store again changes nothing")
    func secondOpen() throws {
        let directory = try Self.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Bifaz.store")
        _ = try Self.writeV1Store(at: url)
        do {
            let first = try BifazStore.makeContainer(at: url)
            #expect(try first.mainContext.fetchCount(FetchDescriptor<ExpenseVATLine>()) == 4)
        }
        let second = try BifazStore.makeContainer(at: url)
        #expect(try second.mainContext.fetchCount(FetchDescriptor<ExpenseVATLine>()) == 4)
        #expect(try second.mainContext.fetchCount(FetchDescriptor<Expense>()) == 6)
    }

    @Test("A v2 store opens in v3: same expenses and lines, new fields at their defaults, rules keep their date")
    func v2ToV3() throws {
        let directory = try Self.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Bifaz.store")
        typealias V2 = BifazSchemaV2
        let nextDate = Date(timeIntervalSince1970: 1_765_000_000)
        var before: [Snapshot] = []
        do {
            let schema = Schema(versionedSchema: V2.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            let software = V2.ExpenseCategory(name: "Logiciels", space: .pro, seedKey: "category.pro.software")
            context.insert(software)
            let client = V2.Tag(name: "Studio Nord", kind: .client)
            context.insert(client)
            let expense = V2.Expense(amount: decimal("71.99"), merchant: "Adobe", space: .pro, category: software,
                                     vatRate: decimal("0.2"), vatAmount: decimal("12.00"))
            context.insert(expense)
            expense.tags = [client]
            let line = V2.ExpenseVATLine(rate: decimal("0.2"), base: decimal("59.99"), vat: decimal("12.00"), total: decimal("71.99"))
            context.insert(line)
            line.expense = expense
            let rule = V2.RecurringRule(amount: decimal("71.99"), merchant: "Adobe", space: .pro, category: software,
                                        frequency: .monthly, nextDate: nextDate)
            context.insert(rule)
            context.insert(V2.MerchantRule(merchantName: "Adobe", space: .pro, category: software))
            try context.save()
            before = [Snapshot(id: expense.id, amount: expense.amount, amountInEUR: expense.amountInEUR, currencyCode: expense.currencyCode,
                               date: expense.date, merchant: expense.merchant, space: expense.spaceRawValue, vatRate: expense.vatRate,
                               vatAmount: expense.vatAmount, note: expense.note, source: expense.sourceRawValue,
                               status: expense.statusRawValue, category: software.seedKey, receiptFile: nil, tags: ["Studio Nord"])]
        }

        let container = try BifazStore.makeContainer(at: url)
        let context = container.mainContext
        let expense = try #require(try context.fetch(FetchDescriptor<Expense>()).first)
        let after = Snapshot(id: expense.id, amount: expense.amount, amountInEUR: expense.amountInEUR, currencyCode: expense.currencyCode,
                             date: expense.date, merchant: expense.merchant, space: expense.spaceRawValue, vatRate: expense.vatRate,
                             vatAmount: expense.vatAmount, note: expense.note, source: expense.sourceRawValue,
                             status: expense.statusRawValue, category: expense.category?.seedKey, receiptFile: expense.receipt?.fileName,
                             tags: (expense.tags ?? []).map(\.name))
        #expect([after] == before)
        #expect(expense.sortedVATLines.map(VATPart.init) == [VATPart(rate: decimal("0.2"), base: decimal("59.99"), vat: 12, total: decimal("71.99"))])
        #expect(expense.exchangeRate == nil && expense.recurrenceDate == nil && expense.client?.name == "Studio Nord")
        let tag = try #require(try context.fetch(FetchDescriptor<Tag>()).first)
        #expect(tag.isArchived == false)
        let rule = try #require(try context.fetch(FetchDescriptor<RecurringRule>()).first)
        #expect(rule.startDate == nextDate && rule.nextDate == nextDate && rule.generatedThrough == nil && rule.endDate == nil)
        #expect(try context.fetch(FetchDescriptor<MerchantRule>()).first?.client == nil)
    }
}
