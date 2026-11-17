import Foundation
import SwiftData

/// The editable state of an expense form (quick add and edit).
///
/// Plain value type: the form edits a draft, and only `ExpenseService` turns
/// it into a stored `Expense`, after `validate()` passes.
public struct ExpenseDraft: Equatable {
    public var amount: Decimal?
    public var merchant: String
    public var date: Date
    public var space: Space
    public var category: ExpenseCategory?
    /// Main VAT rate; `nil` when the user is not VAT-registered or the rate is unknown.
    /// Without `secondVAT` it covers the whole amount.
    public var vatRate: VATRate?
    /// A second rate typed by hand, with the part of the amount (TTC) it covers.
    /// The main rate covers the rest.
    public var secondVAT: SecondVAT?
    /// Lines that the two rates above cannot express: read from a receipt (printed
    /// VAT, three rates, a part without VAT) or stored with an expense being edited.
    /// While set they are the expense's VAT; the form clears them when the user
    /// changes the amount or picks a rate by hand.
    public var fixedVATLines: [VATPart]?
    public var note: String
    /// How the expense entered Bifaz (only used when creating).
    public var source: ExpenseSource = .manual

    /// A second VAT rate and the part of the amount (TTC) taxed at it.
    public struct SecondVAT: Equatable, Sendable {
        public var rate: VATRate
        public var total: Decimal?

        public init(rate: VATRate, total: Decimal? = nil) {
            self.rate = rate
            self.total = total
        }
    }

    public init(
        amount: Decimal? = nil,
        merchant: String = "",
        date: Date = .now,
        space: Space = .personal,
        category: ExpenseCategory? = nil,
        vatRate: VATRate? = nil,
        note: String = ""
    ) {
        self.amount = amount
        self.merchant = merchant
        self.date = date
        self.space = space
        self.category = category
        self.vatRate = vatRate
        self.note = note
    }

    /// A draft prefilled from a stored expense, for editing.
    public init(expense: Expense) {
        self.init(
            amount: expense.amount,
            merchant: expense.merchant,
            date: expense.date,
            space: expense.space,
            category: expense.category,
            note: expense.note
        )
        let lines = expense.sortedVATLines.map(VATPart.init)
        if lines.isEmpty {
            vatRate = expense.vatRate.flatMap(VATRate.init(fraction:))
        } else {
            setVAT(lines)
        }
    }

    /// Sets the VAT from lines (read or stored): as one or two hand rates when they
    /// say exactly the same, else as fixed lines.
    public mutating func setVAT(_ lines: [VATPart]) {
        let lines = VATBreakdown.sorted(lines)
        secondVAT = nil
        fixedVATLines = nil
        vatRate = lines.first?.frenchRate
        guard let main = lines.first, let mainRate = main.frenchRate, lines.count <= 2 else {
            fixedVATLines = lines.isEmpty ? nil : lines
            return
        }
        if lines.count == 2, let rate = lines[1].frenchRate {
            secondVAT = SecondVAT(rate: rate, total: lines[1].total)
        }
        vatRate = mainRate
        if vatLines != lines {
            secondVAT = nil
            fixedVATLines = lines
        }
    }

    /// Drops fixed lines and the second rate (the user picked a rate by hand).
    public mutating func clearFixedVAT() {
        fixedVATLines = nil
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case missingAmount
        case amountNotPositive
        case amountTooLarge
        /// The category belongs to the other space.
        case categoryInOtherSpace
        /// A printed VAT that is negative or not below the total (misread).
        case vatNotBelowAmount
        /// The part at the second rate is missing, zero or not below the amount.
        case secondVATPartInvalid
        /// Fixed VAT lines do not add up to the amount.
        case vatLinesDoNotMatchAmount
    }

    /// The first problem that prevents saving, if any.
    public func validate() -> ValidationError? {
        guard let amount else { return .missingAmount }
        guard amount > 0 else { return .amountNotPositive }
        guard amount <= MoneyParser.maximum else { return .amountTooLarge }
        if let fixedVATLines {
            if fixedVATLines.contains(where: { $0.vat < 0 || $0.vat >= $0.total && $0.total > 0 }) { return .vatNotBelowAmount }
            if !VATBreakdown.isConsistent(fixedVATLines, amount: amount) { return .vatLinesDoNotMatchAmount }
        } else if vatRate != nil, let secondVAT {
            guard let part = secondVAT.total, part > 0, part.rounded(scale: 2) < amount.rounded(scale: 2) else {
                return .secondVATPartInvalid
            }
        }
        if let category, category.space != space { return .categoryInOtherSpace }
        return nil
    }

    public var isValid: Bool { validate() == nil }

    /// Merchant without surrounding or repeated whitespace.
    public var normalizedMerchant: String {
        merchant.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The VAT lines this draft saves (see the rounding rule on `VATPart`), largest first.
    /// Empty without a rate or an amount.
    public var vatLines: [VATPart] {
        if let fixedVATLines { return VATBreakdown.sorted(fixedVATLines) }
        guard let amount, amount > 0, let vatRate else { return [] }
        let total = amount.rounded(scale: 2)
        if let secondVAT, secondVAT.rate != vatRate,
           let part = secondVAT.total?.rounded(scale: 2), part > 0, part < total {
            return VATBreakdown.sorted([
                .computed(total: total - part, rate: vatRate.fraction),
                .computed(total: part, rate: secondVAT.rate.fraction),
            ])
        }
        return [.computed(total: total, rate: vatRate.fraction)]
    }

    /// Total VAT of `vatLines`; `nil` without VAT.
    public var vatAmount: Decimal? {
        let lines = vatLines
        return lines.isEmpty ? nil : lines.reduce(0) { $0 + $1.vat }
    }
}
