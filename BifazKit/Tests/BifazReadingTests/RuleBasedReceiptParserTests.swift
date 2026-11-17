import Foundation
import Testing
@testable import BifazReading

// MARK: - Fixtures

/// One synthetic French receipt with what a human can read from it.
struct ReceiptFixture: Decodable, Sendable, CustomTestStringConvertible {
    struct Expected: Decodable, Sendable {
        var merchant: String?
        var date: String?
        var total: String?
        var vatRates: [String]?
        var vatAmount: String?
    }

    var name: String
    var kind: String
    var lines: [String]
    var expected: Expected

    var testDescription: String { name }

    static let all: [ReceiptFixture] = load()

    private static func load() -> [ReceiptFixture] {
        guard let folder = Bundle.module.url(forResource: "Fixtures", withExtension: nil),
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return [] }
        let decoder = JSONDecoder()
        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? decoder.decode(ReceiptFixture.self, from: Data(contentsOf: $0)) }
    }
}

// MARK: - Helpers

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
}()

private let today: Date = paris.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12))!

private func parse(_ lines: [String]) -> ReceiptFields {
    RuleBasedReceiptParser.parse(lines, today: today, calendar: paris)
}

private func parse(_ line: String) -> ReceiptFields { parse([line]) }

private func decimal(_ text: String) -> Decimal { Decimal(string: text)! }

private func day(_ text: String) -> Date {
    let parts = text.split(separator: "-").compactMap { Int($0) }
    return paris.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
}

private func fold(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
}

private func vatRates(of fields: ReceiptFields) -> Set<Decimal> {
    var rates = Set(fields.vatLines.map(\.rate))
    if rates.isEmpty, let single = fields.vatRate { rates.insert(single.value) }
    return rates
}

// MARK: - Corpus

@Suite("Receipt corpus")
struct ReceiptCorpusTests {
    @Test("Fixtures are present")
    func fixturesLoaded() {
        #expect(ReceiptFixture.all.count >= 20, "Fixtures folder missing or unreadable")
    }

    @Test("Merchant", arguments: ReceiptFixture.all.filter { $0.expected.merchant != nil })
    func merchant(_ fixture: ReceiptFixture) throws {
        let expected = try #require(fixture.expected.merchant)
        let actual = try #require(parse(fixture.lines).merchant?.value, "no merchant read, expected \(expected)")
        let (a, e) = (fold(actual), fold(expected))
        #expect(a.contains(e) || e.contains(a), "merchant: expected \(expected), got \(actual)")
    }

    @Test("Date", arguments: ReceiptFixture.all.filter { $0.expected.date != nil })
    func date(_ fixture: ReceiptFixture) throws {
        let expected = day(try #require(fixture.expected.date))
        let actual = try #require(parse(fixture.lines).date?.value, "no date read, expected \(fixture.expected.date ?? "")")
        #expect(paris.isDate(actual, inSameDayAs: expected), "date: expected \(fixture.expected.date ?? ""), got \(actual)")
    }

    @Test("Total", arguments: ReceiptFixture.all.filter { $0.expected.total != nil })
    func total(_ fixture: ReceiptFixture) throws {
        let expected = decimal(try #require(fixture.expected.total))
        let actual = try #require(parse(fixture.lines).total?.value, "no total read, expected \(expected)")
        #expect(actual == expected, "total: expected \(expected), got \(actual)")
    }

    @Test("VAT rates", arguments: ReceiptFixture.all.filter { $0.expected.vatRates != nil })
    func rates(_ fixture: ReceiptFixture) throws {
        let expected = Set(try #require(fixture.expected.vatRates).map(decimal))
        let actual = vatRates(of: parse(fixture.lines))
        #expect(actual == expected, "VAT rates: expected \(expected.sorted()), got \(actual.sorted())")
    }

    @Test("VAT amount", arguments: ReceiptFixture.all.filter { $0.expected.vatAmount != nil })
    func vatAmount(_ fixture: ReceiptFixture) throws {
        let expected = decimal(try #require(fixture.expected.vatAmount))
        let actual = try #require(parse(fixture.lines).vatAmount?.value, "no VAT amount read, expected \(expected)")
        #expect(actual == expected, "VAT amount: expected \(expected), got \(actual)")
    }
}

// MARK: - Single lines

@Suite("Parser, single lines")
struct ParserLineTests {
    @Test("Amount formats", arguments: [
        ("42,50", "42.50"), ("42.50", "42.50"), ("42,50 €", "42.50"), ("42,50 EUR", "42.50"),
        ("€ 42,50", "42.50"), ("EUR 42,50", "42.50"), ("€42,50", "42.50"),
        ("1 234,56", "1234.56"), ("1 234,56 €", "1234.56"), ("1.234,56", "1234.56"),
        ("1234,56", "1234.56"), ("12,5", "12.50"),
    ])
    func amountFormats(printed: String, expected: String) {
        #expect(parse("TOTAL TTC  \(printed)").total?.value == decimal(expected))
    }

    @Test("Rate formats", arguments: [
        ("TVA 20%  3,50", "0.20"), ("TVA 20 %  3,50", "0.20"), ("TVA 20,00%  3,50", "0.20"),
        ("TVA 5,5%  3,50", "0.055"), ("TVA 5,50 %  3,50", "0.055"), ("TVA 5.5%  3,50", "0.055"),
        ("TVA 2,1%  3,50", "0.021"), ("TVA 2,10%  3,50", "0.021"), ("TVA 10%  3,50", "0.10"),
        ("dont TVA 20,0%  3,50", "0.20"), ("TVA 10% : 3,50", "0.10"), ("TVA (10,00 %)  3,50", "0.10"),
    ])
    func rateFormats(line: String, expected: String) {
        let fields = parse(["TOTAL TTC  42,50 €", line])
        #expect(vatRates(of: fields) == [decimal(expected)])
        #expect(fields.vatAmount?.value == decimal("3.50"))
    }

    @Test("VAT table row gives rate, base, VAT")
    func vatTableRow() {
        let fields = parse(["TOTAL TTC  21,00 €", "TVA  HT  TVA  TTC", "A 20,00%  17,50  3,50  21,00"])
        #expect(fields.vatLines.count == 1)
        #expect(fields.vatLines.first?.rate == decimal("0.20"))
        #expect(fields.vatLines.first?.base == decimal("17.50"))
        #expect(fields.vatLines.first?.vat == decimal("3.50"))
    }

    @Test("TOTAL TTC beats SOUS-TOTAL and TOTAL HT, in any order", arguments: [
        ["SOUS-TOTAL  38,00", "TOTAL HT  35,42", "TOTAL TVA  7,08", "TOTAL TTC  42,50"],
        ["TOTAL TTC  42,50", "TOTAL HT  35,42", "SOUS-TOTAL  38,00"],
        ["TOTAL HT  35,42", "SOUS-TOTAL  38,00", "NET A PAYER  42,50"],
    ])
    func totalPriority(lines: [String]) {
        #expect(parse(lines).total?.value == decimal("42.50"))
    }

    @Test("Payment lines agree with the total", arguments: [
        ["TOTAL TTC  42,50", "CB  42,50"],
        ["TOTAL TTC  42,50", "CARTE BANCAIRE  42,50 EUR"],
        ["A PAYER  42,50", "CB  42,50"],
    ])
    func paymentAgrees(lines: [String]) {
        let fields = parse(lines)
        #expect(fields.total?.value == decimal("42.50"))
        #expect(fields.total?.confidence == .high)
    }

    @Test("RENDU and ESPECES are never the total", arguments: [
        ["TOTAL  12,40", "ESPECES  20,00", "RENDU  7,60"],
        ["A PAYER  12,40", "ESPECES  50,00", "RENDU  37,60"],
        ["ARTICLE  12,40", "TOTAL TTC  12,40", "RENDU  7,60", "ESPECES  20,00"],
    ])
    func cashNeverTotal(lines: [String]) {
        #expect(parse(lines).total?.value == decimal("12.40"))
    }

    @Test("Total split across two lines")
    func splitTotal() {
        #expect(parse(["TOTAL TTC", "42,50 €"]).total?.value == decimal("42.50"))
        #expect(parse(["TOTAL", "42,50"]).total?.value == decimal("42.50"))
    }

    @Test("Date formats", arguments: [
        ("12/11/2026", "2026-11-12"), ("12/11/26", "2026-11-12"), ("12-11-2026", "2026-11-12"),
        ("12.11.2026", "2026-11-12"), ("12 nov. 2026", "2026-11-12"), ("Le 3 octobre 2026", "2026-10-03"),
        ("3 octobre 2026", "2026-10-03"), ("01/12/2025", "2025-12-01"), ("Le 28/10/2026 à 16:34", "2026-10-28"),
    ])
    func dateFormats(printed: String, expected: String) throws {
        let date = try #require(parse(["MAGASIN", printed]).date?.value)
        #expect(paris.isDate(date, inSameDayAs: day(expected)))
    }

    @Test("Nothing readable gives an empty result")
    func emptyInput() {
        #expect(parse([]).isEmpty)
        #expect(parse(["", "   "]).isEmpty)
    }
}
