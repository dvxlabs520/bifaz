import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("Container and entities")
struct ContainerAndEntityTests {
    @Test("In-memory container is created")
    func containerCreates() throws {
        _ = try BifazStore.makeContainer(inMemory: true)
    }

    @Test("Schema contains exactly the 8 entity types")
    func schemaEntities() {
        let names = Set(BifazStore.schema.entities.map(\.name))
        #expect(names == ["Expense", "Receipt", "ExpenseCategory", "Tag", "Budget",
                          "RecurringRule", "ExpenseSession", "MerchantRule"])
        #expect(BifazStore.schema.entities.count == 8)
        #expect(BifazSchemaV1.models.count == 8)
    }

    @Test("Expense round-trips its fields")
    func expenseRoundTrip() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let expense = Expense(
            amount: decimal("42.50"), currencyCode: "USD", amountInEUR: decimal("39.10"),
            date: date, merchant: "Gare", space: .pro, vatRate: decimal("0.2"),
            vatAmount: decimal("7.08"), note: "Train", source: .scanner, status: .needsReview
        )
        context.insert(expense)
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<Expense>()).first)
        #expect(fetched.amount == decimal("42.50"))
        #expect(fetched.currencyCode == "USD")
        #expect(fetched.amountInEUR == decimal("39.10"))
        #expect(fetched.date == date)
        #expect(fetched.merchant == "Gare")
        #expect(fetched.space == .pro)
        #expect(fetched.vatRate == decimal("0.2"))
        #expect(fetched.vatAmount == decimal("7.08"))
        #expect(fetched.note == "Train")
        #expect(fetched.source == .scanner)
        #expect(fetched.status == .needsReview)
    }

    @Test("Expense defaults amountInEUR to amount")
    func expenseDefaultEUR() throws {
        let expense = Expense(amount: decimal("10"), space: .personal)
        #expect(expense.amountInEUR == decimal("10"))
        #expect(expense.vatRate == nil)
    }

    @Test("Receipt round-trips its fields")
    func receiptRoundTrip() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        context.insert(Receipt(fileName: "A1.pdf", fileTypeIdentifier: "com.adobe.pdf",
                               thumbnailFileName: "A1-thumb.jpg", recognizedText: "TOTAL 5"))
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<Receipt>()).first)
        #expect(fetched.fileName == "A1.pdf")
        #expect(fetched.fileTypeIdentifier == "com.adobe.pdf")
        #expect(fetched.thumbnailFileName == "A1-thumb.jpg")
        #expect(fetched.recognizedText == "TOTAL 5")
    }

    @Test("ExpenseCategory round-trips its fields")
    func categoryRoundTrip() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        context.insert(ExpenseCategory(name: "Food", iconName: "fork.knife", colorKey: "orange",
                                       space: .personal, sortOrder: 3))
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<ExpenseCategory>()).first)
        #expect(fetched.name == "Food")
        #expect(fetched.iconName == "fork.knife")
        #expect(fetched.colorKey == "orange")
        #expect(fetched.space == .personal)
        #expect(fetched.sortOrder == 3)
    }

    @Test("Tag round-trips its fields")
    func tagRoundTrip() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        context.insert(Tag(name: "Acme", kind: .project))
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<Tag>()).first)
        #expect(fetched.name == "Acme")
        #expect(fetched.kind == .project)
    }

    @Test("Budget round-trips its fields")
    func budgetRoundTrip() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        context.insert(Budget(category: nil, monthlyAmount: decimal("250.75")))
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<Budget>()).first)
        #expect(fetched.monthlyAmount == decimal("250.75"))
        #expect(fetched.category == nil)
    }

    @Test("RecurringRule round-trips its fields")
    func recurringRoundTrip() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let next = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(RecurringRule(amount: decimal("9.99"), currencyCode: "EUR", merchant: "Netflix",
                                     space: .personal, vatRate: decimal("0.21"), note: "TV",
                                     frequency: .yearly, nextDate: next))
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<RecurringRule>()).first)
        #expect(fetched.amount == decimal("9.99"))
        #expect(fetched.merchant == "Netflix")
        #expect(fetched.space == .personal)
        #expect(fetched.vatRate == decimal("0.21"))
        #expect(fetched.note == "TV")
        #expect(fetched.frequency == .yearly)
        #expect(fetched.nextDate == next)
        #expect(fetched.isActive)
    }

    @Test("ExpenseSession round-trips its fields")
    func sessionRoundTrip() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = ExpenseSession(name: "Trip", space: .pro, startedAt: start)
        context.insert(session)
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<ExpenseSession>()).first)
        #expect(fetched.name == "Trip")
        #expect(fetched.space == .pro)
        #expect(fetched.startedAt == start)
        #expect(fetched.isActive)
        fetched.endedAt = start.addingTimeInterval(60)
        #expect(!fetched.isActive)
    }

    @Test("MerchantRule round-trips its fields")
    func merchantRuleRoundTrip() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        context.insert(MerchantRule(merchantName: "Café de la Gare", space: .pro))
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<MerchantRule>()).first)
        #expect(fetched.merchantName == "Café de la Gare")
        #expect(fetched.merchantKey == "cafe de la gare")
        #expect(fetched.space == .pro)
    }

    @Test("Decimals round-trip exactly", arguments: ["1234.56", "0.1", "0.3", "99999999.99"])
    func decimalRoundTrip(_ text: String) throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        context.insert(Expense(amount: decimal(text), space: .personal))
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<Expense>()).first)
        #expect(fetched.amount == decimal(text))
        #expect(fetched.amount.description == decimal(text).description)
    }

    @Test("0.1 + 0.2 equals 0.3 after save and fetch")
    func decimalSum() throws {
        let container = try BifazStore.makeContainer(inMemory: true)
        defer { withExtendedLifetime(container) {} } // the context does not retain its container
        let context = container.mainContext
        context.insert(Expense(amount: decimal("0.1") + decimal("0.2"), space: .personal))
        try context.save()
        let fetched = try #require(context.fetch(FetchDescriptor<Expense>()).first)
        #expect(fetched.amount == decimal("0.3"))
    }
}
