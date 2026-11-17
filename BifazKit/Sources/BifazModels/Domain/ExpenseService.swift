import Foundation
import SwiftData

/// Creates, updates and deletes expenses. The only place that writes
/// `Expense` from a form, so validation and side effects stay in one spot.
public enum ExpenseService {
    /// Saves a new manual expense. Phase 1 is EUR only.
    @discardableResult
    public static func create(from draft: ExpenseDraft, in context: ModelContext) throws -> Expense {
        if let error = draft.validate() { throw error }
        let expense = Expense(amount: 0, space: draft.space)
        context.insert(expense)
        apply(draft, to: expense)
        MerchantMemory.remember(expense, in: context)
        try context.save()
        return expense
    }

    /// Applies an edited draft to an existing expense.
    public static func update(_ expense: Expense, with draft: ExpenseDraft, in context: ModelContext) throws {
        if let error = draft.validate() { throw error }
        apply(draft, to: expense)
        expense.updatedAt = .now
        MerchantMemory.remember(expense, in: context)
        try context.save()
    }

    /// Deletes an expense (and, by cascade, its receipt).
    public static func delete(_ expense: Expense, in context: ModelContext) throws {
        context.delete(expense)
        try context.save()
    }

    private static func apply(_ draft: ExpenseDraft, to expense: Expense) {
        let amount = (draft.amount ?? 0).rounded(scale: 2)
        expense.amount = amount
        expense.currencyCode = "EUR"
        expense.amountInEUR = amount
        expense.merchant = draft.normalizedMerchant
        expense.date = draft.date
        expense.space = draft.space
        expense.category = draft.category
        expense.vatRate = draft.vatRate?.fraction
        expense.vatAmount = draft.vatAmount
        expense.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ExpenseDraft.ValidationError: LocalizedError {}
