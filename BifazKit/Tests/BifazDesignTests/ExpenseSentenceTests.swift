import Foundation
import Testing
import BifazModels
@testable import BifazDesign

@Suite("Entry sentence")
struct ExpenseSentenceTests {
    static let paris: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()
    static func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        paris.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    static let now = date(11, 19)

    static func text(_ pieces: [SentencePiece]) -> String {
        ExpenseSentence.plainText(pieces)
    }

    static let full = ExpenseSentenceInput(amount: 42, merchant: "Carrefour", categoryName: "Groceries", space: .personal, date: now)

    @Test("The sentence in the three languages", arguments: [
        ("es", "Gasté 42,00 € en Carrefour para Groceries · Personal · hoy"),
        ("fr", "J’ai dépensé 42,00 € chez Carrefour, en Groceries · Perso · aujourd’hui"),
        ("en", "I spent €42.00 at Carrefour on Groceries · Personal · today"),
    ])
    func languages(language: String, expected: String) {
        let locale = Locale(identifier: language == "en" ? "en_GB" : "\(language)_FR")
        let pieces = ExpenseSentence.pieces(Self.full, now: Self.now, calendar: Self.paris, locale: Locale(identifier: language).withRegion(of: locale))
        #expect(Self.text(pieces).replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ") == expected)
    }

    @Test("Every value is a piece, once, in the template's order", arguments: ["es", "fr", "en"])
    func roles(language: String) {
        let pieces = ExpenseSentence.pieces(Self.full, now: Self.now, calendar: Self.paris, locale: Locale(identifier: language))
        let values = pieces.filter(\.isTappable).map(\.role)
        #expect(values == [.amount, .merchant, .category, .space, .date])
        #expect(pieces.map(\.index) == Array(pieces.indices))
        #expect(pieces.filter(\.isTappable).allSatisfy { !$0.accessibilityLabel.isEmpty })
        #expect(pieces.filter { !$0.isTappable }.allSatisfy { $0.accessibilityLabel.isEmpty })
    }

    @Test("Empty values show neutral fillers and say 'not set' to VoiceOver")
    func placeholders() {
        let input = ExpenseSentenceInput(amount: nil, merchant: "  ", categoryName: nil, space: .pro, date: Self.now)
        let pieces = ExpenseSentence.pieces(input, now: Self.now, calendar: Self.paris, locale: Locale(identifier: "es"))
        let byRole = Dictionary(uniqueKeysWithValues: pieces.filter(\.isTappable).map { ($0.role, $0) })
        #expect(byRole[.merchant]?.text == "un comercio" && byRole[.merchant]?.isPlaceholder == true)
        #expect(byRole[.category]?.text == "una categoría" && byRole[.category]?.isPlaceholder == true)
        #expect(byRole[.amount]?.isPlaceholder == true)
        #expect(byRole[.amount]?.accessibilityLabel == "Importe, sin indicar")
        #expect(byRole[.space]?.text == "Pro" && byRole[.space]?.isPlaceholder == false)
        let english = ExpenseSentence.pieces(input, now: Self.now, calendar: Self.paris, locale: Locale(identifier: "en"))
        #expect(english.first { $0.role == .merchant }?.text == "a shop")
    }

    @Test("Full VoiceOver labels", arguments: [
        ("es", "Importe, 42,00 €", "Comercio, Carrefour", "Espacio, Personal", "Fecha, hoy"),
        ("fr", "Montant, 42,00 €", "Commerçant, Carrefour", "Espace, Perso", "Date, aujourd’hui"),
        ("en", "Amount, €42.00", "Merchant, Carrefour", "Space, Personal", "Date, today"),
    ])
    func labels(language: String, amount: String, merchant: String, space: String, date: String) {
        let pieces = ExpenseSentence.pieces(Self.full, now: Self.now, calendar: Self.paris, locale: Locale(identifier: language))
        let labels = pieces.filter(\.isTappable).map { $0.accessibilityLabel.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ") }
        #expect(labels == [amount, merchant, "\(language == "es" ? "Categoría" : language == "fr" ? "Catégorie" : "Category"), Groceries", space, date])
    }

    @Test("Another currency keeps its code in the amount piece")
    func foreignCurrency() {
        var input = Self.full
        input.amount = 48
        input.currencyCode = "USD"
        let piece = ExpenseSentence.pieces(input, now: Self.now, calendar: Self.paris, locale: Locale(identifier: "fr_FR"))
            .first { $0.role == .amount }
        #expect(piece?.text.contains("48,00") == true)
        #expect(piece?.text.contains("$") == true)
    }

    @Test("Dates: today, yesterday, a day this year, a day another year", arguments: [
        ("es", "hoy", "ayer", "el 3 nov", "el 3 nov 2025"),
        ("fr", "aujourd’hui", "hier", "le 3 nov.", "le 3 nov. 2025"),
        ("en", "today", "yesterday", "on 3 Nov", "on 3 Nov 2025"),
    ])
    func dates(language: String, today: String, yesterday: String, thisYear: String, otherYear: String) {
        let locale = Locale(identifier: language == "en" ? "en_GB" : language == "es" ? "es_ES" : "fr_FR")
        func text(_ date: Date) -> String {
            ExpenseSentence.dateText(date, now: Self.now, calendar: Self.paris, locale: locale)
                .replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
        }
        #expect(text(Self.now) == today)
        #expect(text(Self.date(11, 18)) == yesterday)
        #expect(text(Self.date(11, 3)) == thisYear)
        #expect(text(Self.date(11, 3, year: 2025)) == otherYear)
    }
}

private extension Locale {
    func withRegion(of other: Locale) -> Locale { other }
}
