import Foundation
import Testing
@testable import BifazModels

@Suite("Typed accessors, merchant keys and space filter")
struct EnumAndKeyTests {
    @Test("Expense accessors map to raw values and back")
    func expenseAccessors() {
        let e = Expense(amount: 1, space: .pro)
        e.space = .personal; #expect(e.spaceRawValue == "personal")
        e.source = .applePay; #expect(e.sourceRawValue == "applePay")
        e.status = .receiptPending; #expect(e.statusRawValue == "receiptPending")
        e.spaceRawValue = "pro"; #expect(e.space == .pro)
        e.sourceRawValue = "recurring"; #expect(e.source == .recurring)
        e.statusRawValue = "needsReview"; #expect(e.status == .needsReview)
    }

    @Test("Expense unknown raw values fall back to defaults")
    func expenseFallbacks() {
        let e = Expense(amount: 1, space: .pro)
        e.spaceRawValue = "???"; e.sourceRawValue = "???"; e.statusRawValue = "???"
        #expect(e.space == .personal)
        #expect(e.source == .manual)
        #expect(e.status == .confirmed)
    }

    @Test("Tag kind maps and falls back to client")
    func tagKind() {
        let t = Tag(name: "T", kind: .project)
        #expect(t.kindRawValue == "project")
        t.kindRawValue = "bogus"
        #expect(t.kind == .client)
    }

    @Test("RecurringRule frequency maps and falls back to monthly")
    func frequency() {
        let r = RecurringRule(amount: 1, space: .pro, frequency: .quarterly, nextDate: .now)
        #expect(r.frequencyRawValue == "quarterly")
        r.frequencyRawValue = "bogus"; r.spaceRawValue = "bogus"
        #expect(r.frequency == .monthly)
        #expect(r.space == .personal)
    }

    @Test("ExpenseSession space falls back to pro")
    func sessionFallback() {
        let s = ExpenseSession(name: "S", space: .personal)
        #expect(s.spaceRawValue == "personal")
        s.spaceRawValue = "bogus"
        #expect(s.space == .pro)
    }

    @Test("Category and merchant rule space fall back to personal")
    func otherFallbacks() {
        let c = ExpenseCategory(name: "C", space: .pro)
        c.spaceRawValue = "bogus"
        #expect(c.space == .personal)
        let m = MerchantRule(merchantName: "M", space: .pro)
        m.spaceRawValue = "bogus"
        #expect(m.space == .personal)
    }

    @Test("Merchant key normalises case, accents and whitespace")
    func merchantKey() {
        #expect(MerchantRule.key(for: "  Café  de la GARE ") == "cafe de la gare")
        #expect(MerchantRule.key(for: "Café  de la GARE") == MerchantRule.key(for: "cafe de la gare"))
        #expect(MerchantRule.key(for: "A\tB\nC") == "a b c")
        #expect(MerchantRule.key(for: "   ") == "")
    }

    @Test("SpaceFilter.space maps to a single space or nil")
    func filterSpace() {
        #expect(SpaceFilter.pro.space == .pro)
        #expect(SpaceFilter.personal.space == .personal)
        #expect(SpaceFilter.all.space == nil)
    }

    @Test("SpaceFilter.includes", arguments: [
        (SpaceFilter.all, Space.pro, true), (.all, .personal, true),
        (.pro, .pro, true), (.pro, .personal, false),
        (.personal, .personal, true), (.personal, .pro, false),
    ])
    func filterIncludes(filter: SpaceFilter, space: Space, expected: Bool) {
        #expect(filter.includes(space) == expected)
    }
}
