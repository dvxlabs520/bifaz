import Foundation
import Testing
@testable import BifazModels

@Suite("VAT")
struct VATTests {
    @Test("Each rate has its French fraction", arguments: [
        (VATRate.standard, "0.20"), (.intermediate, "0.10"), (.reduced, "0.055"),
        (.superReduced, "0.021"), (.zero, "0"),
    ])
    func fractions(rate: VATRate, expected: String) {
        #expect(rate.fraction == decimal(expected))
    }

    @Test("init(fraction:) round-trips every rate", arguments: VATRate.allCases)
    func roundTrip(rate: VATRate) {
        #expect(VATRate(fraction: rate.fraction) == rate)
    }

    @Test("Unknown fractions give nil", arguments: ["0.19", "0.2000001", "0.5", "-0.20", "0.055001"])
    func unknown(fraction: String) {
        #expect(VATRate(fraction: decimal(fraction)) == nil)
    }

    @Test("VAT included in a total", arguments: [
        ("120", "0.20", "20"),
        ("110", "0.10", "10"),
        ("105.50", "0.055", "5.50"),
        ("102.10", "0.021", "2.10"),
        ("100", "0.20", "16.67"),
    ])
    func vatAmount(total: String, rate: String, expected: String) {
        #expect(VATCalculator.vatAmount(includedIn: decimal(total), rate: decimal(rate)) == decimal(expected))
    }

    @Test("No VAT for zero or negative totals and zero or negative rates")
    func degenerate() {
        #expect(VATCalculator.vatAmount(includedIn: 0, rate: decimal("0.20")) == 0)
        #expect(VATCalculator.vatAmount(includedIn: -120, rate: decimal("0.20")) == 0)
        #expect(VATCalculator.vatAmount(includedIn: 120, rate: 0) == 0)
        #expect(VATCalculator.vatAmount(includedIn: 120, rate: decimal("-0.20")) == 0)
    }

    @Test("Amount excluding VAT")
    func excludingVAT() {
        #expect(VATCalculator.amountExcludingVAT(120, rate: decimal("0.20")) == 100)
        #expect(VATCalculator.amountExcludingVAT(50, rate: 0) == 50)
    }

    @Test("HT + VAT == TTC over a spread of amounts and every rate", arguments: VATRate.allCases)
    func htPlusVATEqualsTTC(rate: VATRate) {
        for cents in stride(from: 1, through: 99_999, by: 37) {
            let total = Decimal(cents) / 100
            let vat = VATCalculator.vatAmount(includedIn: total, rate: rate.fraction)
            let ht = VATCalculator.amountExcludingVAT(total, rate: rate.fraction)
            #expect(ht + vat == total, "total \(total) rate \(rate)")
            #expect(vat >= 0 && vat <= total, "total \(total) rate \(rate)")
            #expect(vat == vat.rounded(scale: 2), "total \(total) rate \(rate)")
        }
    }
}
