import Foundation
import SwiftData
import Testing
@testable import BifazModels

@Suite("CategoryHint")
struct CategoryHintTests {
    @Test("Kind from the merchant's name", arguments: [
        ("Monoprix", CategoryHint.Kind.groceries),
        ("Carrefour City", .groceries),
        ("Intermarché Express", .groceries),
        ("TotalEnergies", .fuel),
        ("Indigo", .roadAndParking),
        ("Vinci Autoroutes", .roadAndParking),
        ("SNCF", .trainAndTaxi),
        ("G7", .trainAndTaxi),
        ("Brasserie Le Zinc", .restaurant),
        ("Café Le Petit Bouillon", .restaurant),
        ("Restaurant Chez Marcel", .restaurant),
        ("Pharmacie du Centre", .pharmacy),
        ("Free Mobile", .phone),
        ("Adobe", .software),
        ("Hotel Le Magnolia", .lodging),
    ])
    func fromName(_ merchant: String, _ kind: CategoryHint.Kind) {
        #expect(CategoryHint.kind(merchant: merchant, text: "") == kind)
    }

    @Test("Kind from the printed text when the name says nothing")
    func fromText() {
        #expect(CategoryHint.kind(merchant: "Relais du Lac", text: "GAZOLE\nQuantité 38,42 L") == .fuel)
        #expect(CategoryHint.kind(merchant: "Le Comptoir", text: "2 couverts\nPourboire 3,00") == .restaurant)
        #expect(CategoryHint.kind(merchant: "", text: "Péage de Fresnes") == .roadAndParking)
    }

    @Test("No clear hint, no proposal", arguments: [
        ("Amazon", "Câble USB-C"),
        ("Fnac", "MacBook Air"),
        ("IKEA", "Étagère"),
        ("Camille Durand", "Rédaction web"),
        ("Le Grand Hall", "Restaurant 45,00\nParking 12,00\nCouverts 2\nStationnement"),
        ("", ""),
    ])
    func noHint(_ merchant: String, _ text: String) {
        #expect(CategoryHint.kind(merchant: merchant, text: text) == nil)
    }

    @Test("Whole words only: a brand inside another word is not the brand")
    func wholeWords() {
        #expect(CategoryHint.kind(merchant: "La Terrasse", text: "") == nil)
        #expect(CategoryHint.kind(merchant: "Totalement Bio", text: "") == nil)
    }

    @Test("The name wins over the text")
    func nameFirst() {
        #expect(CategoryHint.kind(merchant: "Hotel Le Magnolia", text: "Restaurant\nParking") == .lodging)
    }

    @Test("Every built-in key a hint can point to exists")
    func keysExist() {
        let known = Set(DefaultCategory.all.map(\.key))
        for kind in CategoryHint.Kind.allCases {
            for space in Space.allCases {
                if let key = CategoryHint.seedKey(for: kind, space: space) {
                    #expect(known.contains(key), "\(kind) / \(space): \(key)")
                    #expect(key.contains(".\(space.rawValue)."), "\(key) is not a \(space) category")
                }
            }
        }
    }

    @Test("A supermarket or a pharmacy in Pro: no clear category")
    func proWithoutCategory() {
        #expect(CategoryHint.seedKey(for: .groceries, space: .pro) == nil)
        #expect(CategoryHint.seedKey(for: .pharmacy, space: .pro) == nil)
    }

    // MARK: With a store

    @MainActor
    @Test("Proposal: the built-in category of the receipt's space")
    func proposalFromTable() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)

        let pro = CategoryHint.proposal(merchant: "TotalEnergies", text: "GAZOLE", space: .pro, in: context)
        #expect(pro?.seedKey == "category.pro.car")
        let personal = CategoryHint.proposal(merchant: "TotalEnergies", text: "GAZOLE", space: .personal, in: context)
        #expect(personal?.seedKey == "category.personal.transport")
        #expect(CategoryHint.proposal(merchant: "Amazon", text: "", space: .personal, in: context) == nil)
    }

    @MainActor
    @Test("Proposal: the merchant's last category comes first")
    func proposalFromMemory() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)
        let office = try #require(try context.fetch(FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.seedKey == "category.pro.office" }
        )).first)
        let earlier = Expense(amount: 12, merchant: "MONOPRIX", space: .pro, category: office)
        context.insert(earlier)
        MerchantMemory.remember(earlier, in: context)
        try context.save()

        #expect(CategoryHint.proposal(merchant: "Monoprix", text: "", space: .pro, in: context) === office)
        // In the other space the memory does not apply; the table does.
        let personal = CategoryHint.proposal(merchant: "Monoprix", text: "", space: .personal, in: context)
        #expect(personal?.seedKey == "category.personal.groceries")
    }

    @MainActor
    @Test("Proposal: a deleted built-in category is not brought back")
    func deletedCategory() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)
        try context.delete(model: ExpenseCategory.self, where: #Predicate { $0.seedKey == "category.pro.car" })
        try context.save()
        #expect(CategoryHint.proposal(merchant: "Esso", text: "", space: .pro, in: context) == nil)
    }
}
