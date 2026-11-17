import Foundation
import SwiftData

/// Proposes a category for a read receipt (PLAN §4, phase 2 review).
///
/// In order: the category used last time at the same merchant (`MerchantMemory`),
/// then a small table of frequent French brands and keywords. With no clear
/// hint, nothing is proposed: an empty category is better than a wrong one.
/// The form shows the result as a proposal the user changes with one tap.
public enum CategoryHint {
    /// What the receipt is about, independent of the space.
    public enum Kind: String, CaseIterable, Sendable {
        case groceries, fuel, roadAndParking, trainAndTaxi, restaurant, pharmacy, phone, software, lodging
    }

    /// The category to propose for a receipt, or nil.
    @MainActor
    public static func proposal(
        merchant: String,
        text: String,
        space: Space,
        in context: ModelContext
    ) -> ExpenseCategory? {
        if let remembered = MerchantMemory.suggestion(for: merchant, in: context)?.category,
           remembered.space == space {
            return remembered
        }
        guard let kind = kind(merchant: merchant, text: text),
              let key = seedKey(for: kind, space: space)
        else { return nil }
        let raw = space.rawValue
        var descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.seedKey == key && $0.spaceRawValue == raw }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// The kind of receipt: first from the merchant's name, then from the
    /// printed text. Nil when nothing matches or when the text points to
    /// several kinds (a hotel bill with a restaurant and a car park).
    public static func kind(merchant: String, text: String) -> Kind? {
        let name = words(merchant)
        let fromName = Set(Kind.allCases.filter { kind in nameKeys[kind, default: []].contains { name.contains(" \($0) ") } })
        if fromName.count == 1 { return fromName.first }
        if fromName.count > 1 { return nil }
        let body = words(text)
        let fromText = Set(Kind.allCases.filter { kind in textKeys[kind, default: []].contains { body.contains(" \($0) ") } })
        return fromText.count == 1 ? fromText.first : nil
    }

    /// The built-in category for a kind in a space, or nil when the space has no
    /// fitting one (a supermarket receipt in Pro: no clear category).
    public static func seedKey(for kind: Kind, space: Space) -> String? {
        switch (kind, space) {
        case (.groceries, .personal): "category.personal.groceries"
        case (.groceries, .pro): nil
        case (.fuel, .pro), (.roadAndParking, .pro): "category.pro.car"
        case (.fuel, .personal), (.roadAndParking, .personal), (.trainAndTaxi, .personal): "category.personal.transport"
        case (.trainAndTaxi, .pro): "category.pro.transport"
        case (.restaurant, .pro): "category.pro.meals"
        case (.restaurant, .personal): "category.personal.restaurants"
        case (.pharmacy, .personal): "category.personal.health"
        case (.pharmacy, .pro): nil
        case (.phone, .pro): "category.pro.phone"
        case (.phone, .personal), (.software, .personal): "category.personal.subscriptions"
        case (.software, .pro): "category.pro.software"
        case (.lodging, .pro): "category.pro.lodging"
        case (.lodging, .personal): "category.personal.travel"
        }
    }

    // MARK: Tables (folded: capitals, no accents)

    /// Brands and trade words in the merchant's name.
    static let nameKeys: [Kind: [String]] = [
        .groceries: [
            "MONOPRIX", "CARREFOUR", "FRANPRIX", "LECLERC", "AUCHAN", "INTERMARCHE", "LIDL", "ALDI", "CASINO",
            "SUPER U", "HYPER U", "U EXPRESS", "PICARD", "NATURALIA", "BIOCOOP", "GRAND FRAIS", "COOP",
            "SPAR", "VIVAL", "NETTO", "SUPERMARCHE", "EPICERIE", "PRIMEUR",
        ],
        .fuel: ["TOTALENERGIES", "TOTAL", "ESSO", "SHELL", "AVIA", "BP", "AGIP", "STATION SERVICE"],
        .roadAndParking: [
            "INDIGO", "EFFIA", "SAEMES", "ONEPARK", "ZENPARK", "PARKING", "VINCI AUTOROUTES", "APRR", "SANEF",
            "ASF", "COFIROUTE", "PEAGE",
        ],
        .trainAndTaxi: [
            "SNCF", "OUIGO", "TGV", "TER", "RATP", "TRANSILIEN", "UBER", "G7", "BOLT", "HEETCH", "FREENOW",
            "TAXI", "TAXIS", "VTC", "BLABLACAR", "FLIXBUS",
        ],
        .restaurant: [
            "RESTAURANT", "BRASSERIE", "BISTROT", "BISTRO", "CAFE", "PIZZERIA", "CREPERIE", "TRAITEUR",
            "BOULANGERIE", "PATISSERIE", "MCDONALD", "BURGER KING", "KFC", "STARBUCKS", "BRIOCHE DOREE",
            "PAUL", "DELIVEROO", "UBER EATS", "COLUMBUS CAFE",
        ],
        .pharmacy: ["PHARMACIE", "PARAPHARMACIE"],
        .phone: ["ORANGE", "SOSH", "SFR", "RED BY SFR", "BOUYGUES TELECOM", "FREE MOBILE", "FREE"],
        .software: [
            "ADOBE", "MICROSOFT", "NOTION", "OVH", "OVHCLOUD", "GITHUB", "SLACK", "DROPBOX", "ZOOM", "CANVA",
            "FIGMA", "JETBRAINS", "ATLASSIAN", "OPENAI", "ANTHROPIC",
        ],
        .lodging: ["HOTEL", "IBIS", "NOVOTEL", "MERCURE", "CAMPANILE", "KYRIAD", "B&B HOTELS", "AIRBNB", "BOOKING COM"],
    ]

    /// Words in the printed text that clearly say what was bought.
    static let textKeys: [Kind: [String]] = [
        .fuel: ["GAZOLE", "GASOIL", "SP95", "SP98", "SP95 E10", "E85", "GPL", "CARBURANT"],
        .roadAndParking: ["PEAGE", "STATIONNEMENT", "TICKET DE SORTIE"],
        .trainAndTaxi: ["E BILLET", "BILLET DE TRAIN", "RECU DE COURSE"],
        .restaurant: ["COUVERTS", "SERVICE COMPRIS", "POURBOIRE"],
        .pharmacy: ["ORDONNANCE", "PHARMACIEN"],
        .phone: ["FORFAIT MOBILE", "FORFAIT FREE", "LIGNE MOBILE"],
        .software: ["CREATIVE CLOUD", "MICROSOFT 365", "ABONNEMENT LOGICIEL"],
        .lodging: ["NUITEE", "NUITEES", "TAXE DE SEJOUR"],
    ]

    /// " FOLDED WORDS " for whole-word matching ("TER" does not match "TERRASSE").
    static func words(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "fr_FR"))
            .uppercased()
            .replacing(/[^A-Z0-9&]+/, with: " ")
        return " " + folded + " "
    }
}
