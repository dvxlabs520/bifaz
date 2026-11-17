import Foundation
import Testing
@testable import BifazReading

@Suite("Receipt currency")
struct CurrencyDetectionTests {
    @Test("Every synthetic French receipt is in euros", arguments: ReceiptFixture.all)
    func frenchReceipts(_ fixture: ReceiptFixture) {
        #expect(RuleBasedReceiptParser.parse(fixture.lines).currencyCode == "EUR")
    }

    @Test("Foreign receipts", arguments: [
        (["GITHUB INC", "Copilot Business", "Total  USD 48.00"], "USD"),
        (["Uber", "Trip fare  $23.10", "Total  $25.40"], "USD"),
        (["PRET A MANGER", "Total  £12.50", "Card  £12.50"], "GBP"),
        (["SBB CFF FFS", "Billet Genève - Lausanne", "Total CHF 22.80"], "CHF"),
        (["TIM HORTONS", "Total CA$ 8.45"], "CAD"),
        (["7-ELEVEN", "合計 ¥1,280"], "JPY"),
    ])
    func foreign(lines: [String], code: String) {
        #expect(RuleBasedReceiptParser.currency(in: lines) == code)
    }

    @Test("A euro receipt that mentions another currency stays in euros")
    func euroWins() {
        let lines = ["HOTEL DU LAC", "Nuitée  120,00 €", "Total TTC  120,00 €", "Soit 132.00 USD au taux du jour"]
        #expect(RuleBasedReceiptParser.currency(in: lines) == "EUR")
        #expect(RuleBasedReceiptParser.currency(in: ["Merci de votre visite"]) == "EUR")
        // "EUR" inside a word is not the euro (EUROPE), "USD" inside a word is not dollars.
        #expect(RuleBasedReceiptParser.currency(in: ["EUROPCAR", "TOTAL USD 10.00"]) == "USD")
    }
}
