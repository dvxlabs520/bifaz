import Foundation
import SwiftData

/// The editable state of an expense form (quick add and edit).
///
/// Plain value type: the form edits a draft, and only `ExpenseService` turns
/// it into a stored `Expense`, after `validate()` passes.
public struct ExpenseDraft {
    public var amount: Decimal?
    public var merchant: String
    public var date: Date
    public var space: Space
    public var category: ExpenseCategory?
    /// VAT rate; `nil` when the user is not VAT-registered or the rate is unknown.
    public var vatRate: VATRate?
    public var note: String

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
            vatRate: expense.vatRate.flatMap(VATRate.init(fraction:)),
            note: expense.note
        )
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case missingAmount
        case amountNotPositive
        case amountTooLarge
        /// The category belongs to the other space.
        case categoryInOtherSpace
    }

    /// The first problem that prevents saving, if any.
    public func validate() -> ValidationError? {
        guard let amount else { return .missingAmount }
        guard amount > 0 else { return .amountNotPositive }
        guard amount <= MoneyParser.maximum else { return .amountTooLarge }
        if let category, category.space != space { return .categoryInOtherSpace }
        return nil
    }

    public var isValid: Bool { validate() == nil }

    /// Merchant without surrounding or repeated whitespace.
    public var normalizedMerchant: String {
        merchant.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// VAT amount implied by the amount and rate.
    public var vatAmount: Decimal? {
        guard let amount, let vatRate else { return nil }
        return VATCalculator.vatAmount(includedIn: amount, rate: vatRate.fraction)
    }
}
