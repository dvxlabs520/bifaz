import Foundation
import Testing
import BifazModels
@testable import BifazReading

@Suite("ReceiptReader.combine (hallucination guard)")
struct ReaderCombineTests {
    private let paris: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()
    private var today: Date { paris.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12))! }

    private func dec(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))! }

    private let withVAT = [
        "BOULANGERIE DUPONT", "Le 12/11/2026", "Pain au chocolat  2,00", "TOTAL TTC  42,50 €", "TVA 20%  7,08",
    ]
    private let withoutVAT = [
        "BOULANGERIE DUPONT", "Le 12/11/2026", "Pain au chocolat  2,00", "TOTAL TTC  42,50 €",
    ]

    private func combine(_ model: ModelReceiptParser.Extraction, lines: [String]) -> (rules: ReceiptFields, merged: ReceiptFields) {
        let rules = RuleBasedReceiptParser.parse(lines, today: today, calendar: paris)
        let merged = ReceiptReader.combine(model: model, rules: rules, lines: lines, today: today, calendar: paris)
        return (rules, merged)
    }

    @Test("A model total that is not in the text is ignored")
    func totalNotPrinted() throws {
        let (rules, merged) = combine(.init(totalIncludingVAT: "99.00"), lines: withVAT)
        #expect(try #require(rules.total).value == dec("42.50"))
        #expect(merged.total == rules.total)
    }

    @Test("A model total equal to the rules' total gives high confidence")
    func totalAgrees() throws {
        let (_, merged) = combine(.init(totalIncludingVAT: "42.50"), lines: withVAT)
        #expect(merged.total == ReadValue(dec("42.50"), confidence: .high))
    }

    @Test("A model total printed in the text fills a missing total with medium confidence")
    func totalFillsGap() {
        let lines = ["BOULANGERIE DUPONT", "Pain  2,00", "Montant dû  42,50"]
        let rules = RuleBasedReceiptParser.parse(lines, today: today, calendar: paris)
        let merged = ReceiptReader.combine(model: .init(totalIncludingVAT: "42.50"), rules: ReceiptFields(merchant: rules.merchant), lines: lines, today: today, calendar: paris)
        #expect(merged.total == ReadValue(dec("42.50"), confidence: .medium))
    }

    @Test("A model merchant that is not printed is ignored")
    func merchantNotPrinted() throws {
        let (rules, merged) = combine(.init(merchant: "Boulangerie Martin"), lines: withVAT)
        #expect(rules.merchant != nil)
        #expect(merged.merchant == rules.merchant)
    }

    @Test("A model merchant that is printed and agrees gives high confidence")
    func merchantAgrees() throws {
        let (_, merged) = combine(.init(merchant: "Boulangerie Dupont"), lines: withVAT)
        #expect(try #require(merged.merchant).confidence == .high)
    }

    @Test("A model date that is not printed is ignored")
    func dateNotPrinted() throws {
        let (rules, merged) = combine(.init(date: "2026-11-13"), lines: withVAT)
        #expect(try #require(rules.date).value == paris.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        #expect(merged.date == rules.date)
    }

    @Test("A model VAT rate fills a missing rate with medium confidence and computes the VAT amount")
    func vatRateFillsGap() throws {
        let (rules, merged) = combine(.init(vatRatePercent: 20), lines: withoutVAT)
        #expect(rules.vatRate == nil)
        #expect(merged.vatRate == ReadValue(dec("0.20"), confidence: .medium))
        let expectedVAT = VATCalculator.vatAmount(includedIn: dec("42.50"), rate: dec("0.20"))
        #expect(try #require(merged.vatAmount).value == expectedVAT)
        #expect(expectedVAT == dec("7.08"))
    }

    @Test("With a high-confidence total, the rules win when the model disagrees")
    func rulesWin() throws {
        let lines = ["BOULANGERIE DUPONT", "Le 12/11/2026", "SOUS-TOTAL  38,00", "TOTAL TTC  42,50", "CB  42,50"]
        let (rules, merged) = combine(.init(totalIncludingVAT: "38.00"), lines: lines)
        #expect(try #require(rules.total).confidence == .high)
        #expect(merged.total == rules.total)
        #expect(merged.total?.value == dec("42.50"))
    }
}
