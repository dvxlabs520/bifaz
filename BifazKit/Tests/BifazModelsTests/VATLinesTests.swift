import Foundation
import SwiftData
import Testing
@testable import BifazModels

@Suite("VAT lines (schema v2)")
struct VATLinesTests {
    // MARK: Rule 1: every line adds up

    @Test("A computed line adds up to the cent, for every total from 0,01 to 30,00 at every rate")
    func computedLinesAddUp() {
        for cents in 1...3000 {
            let total = Decimal(cents) / 100
            for rate in VATRate.allCases {
                let part = VATPart.computed(total: total, rate: rate.fraction)
                #expect(part.base + part.vat == total)
                #expect(part.vat >= 0 && part.base >= 0)
            }
        }
    }

    // MARK: Rule 2: typed by hand

    @Test("One rate covers the whole amount")
    func singleRate() {
        let draft = ExpenseDraft(amount: decimal("120"), vatRate: .standard)
        #expect(draft.vatLines == [VATPart(rate: decimal("0.20"), base: 100, vat: 20, total: 120)])
        #expect(draft.vatAmount == 20)
    }

    @Test("Two rates: the main rate takes the rest of the amount")
    func twoRates() {
        var draft = ExpenseDraft(amount: decimal("100"), vatRate: .standard)
        draft.secondVAT = .init(rate: .reduced, total: decimal("30"))
        #expect(draft.validate() == nil)
        #expect(draft.vatLines == [
            VATPart(rate: decimal("0.20"), base: decimal("58.33"), vat: decimal("11.67"), total: 70),
            VATPart(rate: decimal("0.055"), base: decimal("28.44"), vat: decimal("1.56"), total: 30),
        ])
        #expect(draft.vatAmount == decimal("13.23"))
        #expect(VATBreakdown.isConsistent(draft.vatLines, amount: 100))
    }

    @Test("Two hand rates always add up to the amount", arguments: [
        ("0.03", "0.01"), ("10.00", "9.99"), ("47.13", "12.40"), ("1234.56", "0.07"), ("999.99", "333.33"),
    ])
    func twoRatesAddUp(amount: String, part: String) {
        for main in VATRate.allCases {
            for second in VATRate.allCases where second != main {
                var draft = ExpenseDraft(amount: decimal(amount), vatRate: main)
                draft.secondVAT = .init(rate: second, total: decimal(part))
                #expect(draft.vatLines.count == 2)
                #expect(VATBreakdown.isConsistent(draft.vatLines, amount: decimal(amount)))
            }
        }
    }

    @Test("A second part that is missing, zero or not below the amount is refused")
    func secondPartInvalid() {
        for part in [nil, decimal("0"), decimal("50"), decimal("60")] {
            var draft = ExpenseDraft(amount: 50, vatRate: .standard)
            draft.secondVAT = .init(rate: .reduced, total: part)
            #expect(draft.validate() == .secondVATPartInvalid)
        }
    }

    @Test("The same rate twice is one line")
    func sameRateTwice() {
        var draft = ExpenseDraft(amount: 50, vatRate: .standard)
        draft.secondVAT = .init(rate: .standard, total: 20)
        #expect(draft.vatLines == [.computed(total: 50, rate: decimal("0.20"))])
    }

    // MARK: Rule 3: printed lines

    @Test("Printed lines that add up are kept as printed")
    func printedExact() {
        let lines = VATBreakdown.lines(fromPrinted: [
            PrintedVATLine(rate: decimal("0.055"), base: decimal("10.00"), vat: decimal("0.55")),
            PrintedVATLine(rate: decimal("0.20"), base: decimal("5.00"), vat: decimal("1.00")),
        ], total: decimal("16.55"))
        #expect(lines == [
            VATPart(rate: decimal("0.055"), base: decimal("10.00"), vat: decimal("0.55"), total: decimal("10.55")),
            VATPart(rate: decimal("0.20"), base: decimal("5.00"), vat: decimal("1.00"), total: decimal("6.00")),
        ])
    }

    @Test("A cent of rounding on the receipt goes to the base of the largest line")
    func printedRoundingCent() {
        let lines = VATBreakdown.lines(fromPrinted: [
            PrintedVATLine(rate: decimal("0.055"), base: decimal("10.00"), vat: decimal("0.55")),
            PrintedVATLine(rate: decimal("0.20"), base: decimal("5.00"), vat: decimal("1.00")),
        ], total: decimal("16.56"))
        #expect(lines.first == VATPart(rate: decimal("0.055"), base: decimal("10.01"), vat: decimal("0.55"), total: decimal("10.56")))
        #expect(VATBreakdown.isConsistent(lines, amount: decimal("16.56")))
    }

    @Test("A part without VAT (tip) becomes a 0 % line")
    func printedTip() {
        let lines = VATBreakdown.lines(fromPrinted: [
            PrintedVATLine(rate: decimal("0.10"), base: decimal("36.36"), vat: decimal("3.64")),
        ], total: decimal("43.00"))
        #expect(lines == [
            VATPart(rate: decimal("0.10"), base: decimal("36.36"), vat: decimal("3.64"), total: decimal("40.00")),
            VATPart(rate: 0, base: decimal("3.00"), vat: 0, total: decimal("3.00")),
        ])
    }

    @Test("Lines that add up to more than the total are a misread: one rate for the whole amount")
    func printedMisread() {
        let lines = VATBreakdown.lines(fromPrinted: [
            PrintedVATLine(rate: decimal("0.20"), base: decimal("50.00"), vat: decimal("10.00")),
            PrintedVATLine(rate: decimal("0.055"), base: decimal("5.00"), vat: decimal("0.28")),
        ], total: decimal("24.00"))
        #expect(lines == [.computed(total: decimal("24.00"), rate: decimal("0.20"))])
    }

    @Test("A rate without amounts covers the total, or the rest of it")
    func printedWithoutAmounts() {
        #expect(VATBreakdown.lines(fromPrinted: [PrintedVATLine(rate: decimal("0.20"))], total: 12)
            == [.computed(total: 12, rate: decimal("0.20"))])
        let rest = VATBreakdown.lines(fromPrinted: [
            PrintedVATLine(rate: decimal("0.055"), base: decimal("10.00"), vat: decimal("0.55")),
            PrintedVATLine(rate: decimal("0.20")),
        ], total: decimal("22.55"))
        #expect(rest.count == 2)
        #expect(rest.contains(.computed(total: 12, rate: decimal("0.20"))))
        #expect(VATBreakdown.isConsistent(rest, amount: decimal("22.55")))
    }

    @Test("Whatever is printed, the lines add up to the total", arguments: 0..<200)
    func printedAlwaysConsistent(seed: Int) {
        var rng = SeededGenerator(seed: UInt64(seed + 1))
        let rates = VATRate.allCases.map(\.fraction)
        let printed = (0..<Int.random(in: 1...3, using: &rng)).map { _ in
            let base = Decimal(Int.random(in: 1...20_000, using: &rng)) / 100
            let rate = rates.randomElement(using: &rng)!
            switch Int.random(in: 0...3, using: &rng) {
            case 0: return PrintedVATLine(rate: rate, base: base, vat: (base * rate).rounded(scale: 2))
            case 1: return PrintedVATLine(rate: rate, base: base)
            case 2: return PrintedVATLine(rate: rate, vat: (base * rate).rounded(scale: 2))
            default: return PrintedVATLine(rate: rate)
            }
        }
        let total = Decimal(Int.random(in: 1...60_000, using: &rng)) / 100
        let lines = VATBreakdown.lines(fromPrinted: printed, total: total)
        #expect(!lines.isEmpty)
        #expect(VATBreakdown.isConsistent(lines, amount: total), "\(printed) → \(lines)")
    }

    // MARK: Draft round trip

    static let threeRates = [
        VATPart(rate: decimal("0.055"), base: decimal("10.00"), vat: decimal("0.55"), total: decimal("10.55")),
        VATPart(rate: decimal("0.10"), base: decimal("10.00"), vat: decimal("1.00"), total: decimal("11.00")),
        VATPart(rate: decimal("0.20"), base: decimal("5.00"), vat: decimal("1.00"), total: decimal("6.00")),
    ].sorted { $0.total > $1.total }

    @Test("Lines a hand rate can say become hand rates; the rest stay fixed")
    func setVAT() {
        var draft = ExpenseDraft(amount: 100)
        draft.setVAT([.computed(total: 70, rate: decimal("0.20")), .computed(total: 30, rate: decimal("0.055"))])
        #expect(draft.vatRate == .standard)
        #expect(draft.secondVAT == .init(rate: .reduced, total: 30))
        #expect(draft.fixedVATLines == nil)

        // Three rates: no hand form says that.
        let printed = Self.threeRates
        var read = ExpenseDraft(amount: decimal("27.55"))
        read.setVAT(printed)
        #expect(read.fixedVATLines == printed)
        #expect(read.vatRate == .intermediate)
        #expect(read.vatLines == printed)
        #expect(read.vatAmount == decimal("2.55"))
    }

    @Test("Fixed lines that no longer match the amount are refused")
    func fixedLinesMismatch() {
        var draft = ExpenseDraft(amount: decimal("27.55"))
        draft.setVAT(Self.threeRates)
        #expect(draft.validate() == nil)
        draft.amount = 20
        #expect(draft.validate() == .vatLinesDoNotMatchAmount)
        draft.clearFixedVAT()
        #expect(draft.validate() == nil)
        #expect(draft.vatLines == [.computed(total: 20, rate: decimal("0.10"))])
    }

    // MARK: Stored

    @MainActor
    @Test("Saving stores one line per rate, the main rate and the total VAT")
    func serviceStoresLines() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var draft = ExpenseDraft(amount: 100, space: .pro, vatRate: .standard)
        draft.secondVAT = .init(rate: .reduced, total: 30)
        let expense = try ExpenseService.create(from: draft, in: context)
        #expect(expense.sortedVATLines.map(VATPart.init) == draft.vatLines)
        #expect(expense.vatRate == decimal("0.20"))
        #expect(expense.vatAmount == decimal("13.23"))

        var single = ExpenseDraft(expense: expense)
        #expect(single == draft)
        single.secondVAT = nil
        try ExpenseService.update(expense, with: single, in: context)
        #expect(expense.sortedVATLines.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<ExpenseVATLine>()) == 1)
        #expect(expense.vatAmount == decimal("16.67"))

        single.vatRate = nil
        try ExpenseService.update(expense, with: single, in: context)
        #expect(try context.fetchCount(FetchDescriptor<ExpenseVATLine>()) == 0)
        #expect(expense.vatRate == nil && expense.vatAmount == nil)
    }

    @MainActor
    @Test("Deleting an expense deletes its lines")
    func cascade() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let expense = try ExpenseService.create(from: ExpenseDraft(amount: 12, space: .pro, vatRate: .standard), in: context)
        #expect(try context.fetchCount(FetchDescriptor<ExpenseVATLine>()) == 1)
        try ExpenseService.delete(expense, in: context)
        #expect(try context.fetchCount(FetchDescriptor<ExpenseVATLine>()) == 0)
    }

    @MainActor
    @Test("Editing another field keeps lines a hand rate cannot say, untouched")
    func editKeepsFixedLines() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var draft = ExpenseDraft(amount: decimal("43"), space: .pro)
        draft.setVAT(VATBreakdown.lines(fromPrinted: [
            PrintedVATLine(rate: decimal("0.10"), base: decimal("36.37"), vat: decimal("3.63")),
        ], total: decimal("43")))
        #expect(draft.fixedVATLines != nil)
        let expense = try ExpenseService.create(from: draft, in: context)
        let before = expense.sortedVATLines.map(\.persistentModelID)
        var edit = ExpenseDraft(expense: expense)
        edit.note = "Client"
        try ExpenseService.update(expense, with: edit, in: context)
        #expect(expense.sortedVATLines.map(\.persistentModelID) == before)
        #expect(expense.vatAmount == decimal("3.63"))
    }
}

/// Small deterministic generator (SplitMix64) for generated data sets.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
