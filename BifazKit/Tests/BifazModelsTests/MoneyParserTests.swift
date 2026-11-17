import Foundation
import Testing
@testable import BifazModels

@Suite("MoneyParser")
struct MoneyParserTests {
    @Test("Common formats parse to the exact decimal", arguments: [
        ("12,50", "12.50"),
        ("12.50", "12.50"),
        ("1 234,56", "1234.56"),
        ("1\u{00A0}234,56", "1234.56"),
        ("1\u{202F}234,56", "1234.56"),
        ("1.234,56", "1234.56"),
        ("1,234.56", "1234.56"),
        ("1,234,567", "1234567"),
        ("€ 9,99", "9.99"),
        ("9,99 €", "9.99"),
        ("0", "0"),
        ("7", "7"),
    ])
    func formats(input: String, expected: String) {
        #expect(MoneyParser.parse(input, locale: frLocale) == decimal(expected))
        #expect(MoneyParser.parse(input, locale: enLocale) == decimal(expected))
    }

    @Test("Three digits after a lone separator depend on the locale")
    func ambiguousGrouping() {
        #expect(MoneyParser.parse("1,234", locale: frLocale) == decimal("1.23"))
        #expect(MoneyParser.parse("1,234", locale: enLocale) == decimal("1234"))
        #expect(MoneyParser.parse("1.234", locale: frLocale) == decimal("1234"))
        #expect(MoneyParser.parse("1.234", locale: enLocale) == decimal("1.23"))
    }

    @Test("More than two decimals round to the cent")
    func rounding() {
        #expect(MoneyParser.parse("0,005", locale: frLocale) == decimal("0.01"))
        #expect(MoneyParser.parse("0,005", locale: enLocale) == decimal("0.01")) // a lone 0 is never grouped
        #expect(MoneyParser.parse("2,345", locale: frLocale) == decimal("2.35"))
        #expect(MoneyParser.parse("2,3449", locale: frLocale) == decimal("2.34"))
    }

    @Test("Unparseable or negative input is rejected", arguments: ["", " ", "abc", "-5", "−5", "5-", "€", ",", "."])
    func rejected(input: String) {
        #expect(MoneyParser.parse(input, locale: frLocale) == nil)
    }

    @Test("The maximum is accepted, anything above is rejected")
    func maximum() {
        #expect(MoneyParser.parse("10000000", locale: frLocale) == MoneyParser.maximum)
        #expect(MoneyParser.parse("10000000,01", locale: frLocale) == nil)
        #expect(MoneyParser.parse("99999999", locale: frLocale) == nil)
    }
}

@Suite("Decimal.rounded(scale:)")
struct DecimalRoundingTests {
    @Test("Half rounds away from zero", arguments: [
        ("2.345", "2.35"), ("2.344", "2.34"), ("2.346", "2.35"), ("0.005", "0.01"), ("0.004", "0"),
        ("-2.345", "-2.35"), ("-2.344", "-2.34"), ("-0.005", "-0.01"), ("10", "10"),
    ])
    func twoPlaces(input: String, expected: String) {
        #expect(decimal(input).rounded(scale: 2) == decimal(expected))
    }

    @Test("Other scales")
    func otherScales() {
        #expect(decimal("2.5").rounded(scale: 0) == 3)
        #expect(decimal("1.2345").rounded(scale: 3) == decimal("1.235"))
        #expect(decimal("2.345").rounded() == decimal("2.35"))
    }
}
