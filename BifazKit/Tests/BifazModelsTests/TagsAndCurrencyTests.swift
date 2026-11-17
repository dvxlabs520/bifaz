import Foundation
import SwiftData
import Testing
@testable import BifazModels

@MainActor
@Suite("Tags and currency")
struct TagsAndCurrencyTests {
    // MARK: Tags

    @Test("One tag per name and kind; rename, archive and delete")
    func tagLifecycle() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let a = try TagService.create("  Studio   Nord ", kind: .client, in: context)
        #expect(a.name == "Studio Nord")
        #expect(try TagService.create("studio nórd", kind: .client, in: context) === a)
        let project = try TagService.create("Studio Nord", kind: .project, in: context)
        #expect(project !== a)
        #expect(throws: TagService.ValidationError.emptyName) { try TagService.create("  ", kind: .client, in: context) }

        let b = try TagService.create("ACME", kind: .client, in: context)
        #expect(throws: TagService.ValidationError.duplicateName) { try TagService.rename(b, to: "STUDIO NORD", in: context) }
        try TagService.rename(b, to: "Acme SAS", in: context)

        try TagService.setArchived(b, true, in: context)
        #expect(try TagService.tags(.client, in: context).map(\.name) == ["Studio Nord"])
        #expect(try TagService.tags(.client, includingArchived: true, in: context).count == 2)
        // Creating an archived name brings it back.
        #expect(try TagService.create("acme sas", kind: .client, in: context).isArchived == false)

        var draft = ExpenseDraft(amount: 10, space: .pro)
        draft.client = a
        draft.project = project
        let expense = try ExpenseService.create(from: draft, in: context)
        #expect(expense.client === a && expense.project === project)
        try TagService.delete(a, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Expense>()) == 1)
        #expect(expense.client == nil && expense.project === project)
    }

    @Test("Tags exist only in Pro; the merchant memory proposes them")
    func tagsProOnly() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let client = try TagService.create("Studio Nord", kind: .client, in: context)
        var draft = ExpenseDraft(amount: 30, merchant: "Uber", space: .pro)
        draft.client = client
        let pro = try ExpenseService.create(from: draft, in: context)
        #expect(MerchantMemory.suggestion(for: "UBER", in: context)?.client === client)

        draft.space = .personal
        let personal = try ExpenseService.create(from: draft, in: context)
        #expect(personal.tags?.isEmpty == true)
        // A personal expense does not erase what Pro learned.
        #expect(MerchantMemory.suggestion(for: "Uber", in: context)?.client === client)

        var edit = ExpenseDraft(expense: pro)
        #expect(edit.client === client)
        edit.client = nil
        try ExpenseService.update(pro, with: edit, in: context)
        #expect(pro.client == nil)
        #expect(MerchantMemory.suggestion(for: "Uber", in: context)?.client == nil)
    }

    @Test("History filter by client and project")
    func tagFilter() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let a = try TagService.create("A", kind: .client, in: context)
        let p = try TagService.create("P", kind: .project, in: context)
        for (amount, client, project) in [(1, a, p), (2, a, nil), (4, nil, p), (8, nil, nil)] as [(Int, Tag?, Tag?)] {
            var draft = ExpenseDraft(amount: Decimal(amount), space: .pro)
            draft.client = client
            draft.project = project
            try ExpenseService.create(from: draft, in: context)
        }
        let total = { (filter: ExpenseFilter) in try ExpenseTotals(filter.fetch(in: context)).total }
        #expect(try total(ExpenseFilter(tagIDs: [a.id])) == 3)
        #expect(try total(ExpenseFilter(tagIDs: [p.id])) == 5)
        #expect(try total(ExpenseFilter(tagIDs: [a.id, p.id])) == 1)
        #expect(ExpenseFilter(tagIDs: [a.id]).activeRefinementCount == 1)
    }

    // MARK: Currency

    static let usd = ExchangeRateQuote(currencyCode: "USD", rate: decimal("1.0989"), date: parisDate(2026, 11, 17), source: .ecb)

    @Test("A foreign amount is saved with its euros and its rate, fixed")
    func foreignExpense() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var draft = ExpenseDraft(amount: 48, merchant: "GitHub", space: .pro)
        draft.currencyCode = "USD"
        #expect(draft.validate() == .missingExchangeRate)
        draft.exchangeRate = Self.usd
        #expect(draft.validate() == nil)
        #expect(draft.amountInEUR == decimal("43.68"))
        let expense = try ExpenseService.create(from: draft, in: context)
        #expect(expense.amount == 48 && expense.currencyCode == "USD")
        #expect(expense.amountInEUR == decimal("43.68"))
        #expect(expense.exchangeRate == decimal("1.0989") && expense.exchangeRateSource == .ecb)
        #expect(expense.exchangeRateDate == Self.usd.date)

        // Editing another field keeps the rate; the Summary counts euros.
        var edit = ExpenseDraft(expense: expense)
        #expect(edit.exchangeRate == Self.usd)
        edit.note = "Copilot"
        try ExpenseService.update(expense, with: edit, in: context)
        #expect(expense.exchangeRate == decimal("1.0989") && expense.amountInEUR == decimal("43.68"))
        #expect(ExpenseTotals([expense]).total == decimal("43.68"))
        #expect(ExpenseFigure(expense).amount == decimal("43.68"))
    }

    @Test("The euros the bank charged win and imply a manual rate")
    func euroOverride() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var draft = ExpenseDraft(amount: 48, space: .personal)
        draft.currencyCode = "USD"
        draft.exchangeRate = Self.usd
        draft.amountInEUROverride = decimal("44.10")
        let expense = try ExpenseService.create(from: draft, in: context)
        #expect(expense.amountInEUR == decimal("44.10"))
        #expect(expense.exchangeRateSource == .manual)
        #expect(expense.exchangeRate == decimal("1.0884353741"))
        draft.amountInEUROverride = 0
        #expect(draft.validate() == .euroAmountInvalid)
    }

    @Test("Back to euros clears the rate")
    func backToEuros() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var draft = ExpenseDraft(amount: 48, space: .personal)
        draft.currencyCode = "USD"
        draft.exchangeRate = Self.usd
        let expense = try ExpenseService.create(from: draft, in: context)
        var edit = ExpenseDraft(expense: expense)
        edit.currencyCode = "EUR"
        try ExpenseService.update(expense, with: edit, in: context)
        #expect(expense.amountInEUR == 48 && expense.exchangeRate == nil && expense.exchangeRateSourceRawValue == nil)
    }

    @Test("VAT of a foreign expense is counted in euros")
    func foreignVAT() throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        var draft = ExpenseDraft(amount: 120, space: .pro, vatRate: .standard)
        draft.currencyCode = "GBP"
        draft.exchangeRate = ExchangeRateQuote(currencyCode: "GBP", rate: decimal("0.8"), date: .now, source: .manual)
        let expense = try ExpenseService.create(from: draft, in: context)
        #expect(expense.vatAmount == 20) // in GBP
        #expect(expense.vatAmountInEUR == 25)
        #expect(ExpenseTotals([expense]).proVAT == 25)
        #expect(ExpenseFigure(expense).vatLines == [VATPart(rate: decimal("0.20"), base: 125, vat: 25, total: 150)])
    }
}
