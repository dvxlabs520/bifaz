import Foundation
import Testing
@testable import BifazReading

@Suite("Merchant name")
struct MerchantNameTests {
    /// What the rules show for each synthetic receipt, and whether it may be marked sure.
    /// A brand is sure; a name re-cased from capitals, or not a brand, is to review.
    static let expectations: [String: (name: String, sure: Bool)] = [
        "adobe_creative_cloud": ("Adobe", true),
        "amazon_fr_facture": ("Amazon", true),
        "boulangerie_sans_tva": ("Au Fournil de Paul", false),
        "cafe_petit_bouillon": ("Café Le Petit Bouillon", false),
        "carrefour_city_snack": ("Carrefour City", true),
        "fnac_ordinateur": ("Fnac", true),
        "franprix_especes": ("Franprix", true),
        "free_mobile_facture": ("Free Mobile", true),
        "hotel_magnolia": ("Hotel Le Magnolia", false),
        "ikea_commande": ("IKEA", true),
        "indigo_parking": ("Indigo", true),
        "intermarche_total_coupe": ("Intermarché Express", true),
        "micro_entrepreneur_293b": ("Camille Durand", false),
        "monoprix_courses": ("Monoprix", true),
        "pharmacie_centre": ("Pharmacie du Centre", false),
        "restaurant_chez_marcel_ocr": ("Restaurant Chez Marcel", false),
        "restaurant_zinc_pourboire": ("Brasserie Le Zinc", false),
        "sncf_eticket": ("SNCF", true),
        "taxi_g7": ("G7", true),
        "totalenergies_gazole": ("TotalEnergies", true),
    ]

    @Test("Every synthetic receipt has an expected name")
    func coverage() {
        let names = Set(ReceiptFixture.all.map(\.name))
        #expect(names == Set(Self.expectations.keys))
    }

    @Test("Name and confidence on the synthetic receipts", arguments: ReceiptFixture.all)
    func syntheticReceipt(_ fixture: ReceiptFixture) throws {
        let expected = try #require(Self.expectations[fixture.name])
        let merchant = try #require(RuleBasedReceiptParser.parse(fixture.lines).merchant)
        #expect(merchant.value == expected.name)
        #expect((merchant.confidence == .high) == expected.sure, "confidence \(merchant.confidence)")
    }

    @Test("Capitals are re-cased without breaking acronyms", arguments: [
        ("TOTALENERGIES RELAIS A6 - AIRE DE BEAUNE", "Totalenergies Relais A6 - Aire de Beaune"),
        ("PHARMACIE DU CENTRE", "Pharmacie du Centre"),
        ("PARKING SAINT-GEORGES", "Parking Saint-Georges"),
        ("SNCF VOYAGEURS", "SNCF Voyageurs"),
        ("TAXIS G7", "Taxis G7"),
        ("HÔTEL D'ANGLETERRE", "Hôtel d'Angleterre"),
        ("BHV MARAIS", "BHV Marais"),
        ("AU BON PAIN", "Au Bon Pain"),
    ])
    func recasing(_ printed: String, _ expected: String) {
        let result = RuleBasedReceiptParser.normalizedMerchant(printed)
        #expect(result.name == expected)
        #expect(result.guessedCase)
    }

    @Test("Mixed case is kept as printed", arguments: ["TotalEnergies", "Café Le Petit Bouillon", "McDonald's"])
    func mixedCase(_ printed: String) {
        let result = RuleBasedReceiptParser.normalizedMerchant(printed)
        #expect(result.name == printed)
        #expect(!result.guessedCase)
    }

    @Test("A store line is shown as its brand", arguments: [
        ("TOTALENERGIES RELAIS A6 - AIRE DE BEAUNE", "TotalEnergies"),
        ("SNCF VOYAGEURS", "SNCF"),
        ("TAXIS G7", "G7"),
        ("CARREFOUR CITY LYON PART-DIEU", "Carrefour City"),
        ("IKEA FRANCE SAS", "IKEA"),
    ])
    func brandFromLine(_ line: String, _ brand: String) {
        #expect(RuleBasedReceiptParser.brand(startingLine: .init(line)) == brand)
    }

    @Test("A brand word inside a name is not the brand")
    func brandInsideName() {
        #expect(RuleBasedReceiptParser.brand(startingLine: .init("AU FOURNIL DE PAUL")) == nil)
        #expect(RuleBasedReceiptParser.brand(startingLine: .init("JUS D'ORANGE")) == nil)
    }

    @Test("The model's full store line gives way to the brand")
    func modelStoreLine() {
        let lines = ["TOTALENERGIES RELAIS A6 - AIRE DE BEAUNE", "21200 BEAUNE", "02/11/2026", "TOTAL TTC  64,89 €"]
        let rules = RuleBasedReceiptParser.parse(lines)
        let merged = ReceiptReader.combine(
            model: .init(merchant: "TOTALENERGIES RELAIS A6 - AIRE DE BEAUNE"),
            rules: rules, lines: lines, today: .now, calendar: .current
        )
        #expect(merged.merchant == ReadValue("TotalEnergies", confidence: .high))
    }

    @Test("A model name in capitals that agrees is still to review")
    func modelCapitals() {
        let lines = ["LE COMPTOIR DU MARCHE", "12/11/2026", "TOTAL TTC  18,00 €"]
        let rules = RuleBasedReceiptParser.parse(lines)
        let merged = ReceiptReader.combine(
            model: .init(merchant: "LE COMPTOIR DU MARCHE"),
            rules: rules, lines: lines, today: .now, calendar: .current
        )
        #expect(merged.merchant == ReadValue("Le Comptoir du Marche", confidence: .medium))
    }
}
