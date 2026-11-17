import Foundation
import SwiftData

/// Creates, updates and deletes expenses. The only place that writes
/// `Expense` from a form, so validation and side effects stay in one spot.
public enum ExpenseService {
    /// Saves a new expense, optionally with its receipt (files already stored). EUR only for now.
    @discardableResult
    public static func create(
        from draft: ExpenseDraft,
        receipt: StoredReceiptFiles? = nil,
        in context: ModelContext
    ) throws -> Expense {
        if let error = draft.validate() { throw error }
        let expense = Expense(amount: 0, space: draft.space, source: draft.source)
        context.insert(expense)
        apply(draft, to: expense)
        if let receipt { attach(receipt, to: expense, in: context) }
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

    /// Attaches (or replaces) the receipt of an existing expense. A "receipt
    /// missing" expense becomes confirmed. Old files are removed after saving.
    public static func attachReceipt(
        _ receipt: StoredReceiptFiles,
        to expense: Expense,
        in context: ModelContext,
        store: ReceiptStore?
    ) throws {
        let previous = expense.receipt
        attach(receipt, to: expense, in: context)
        if let previous { context.delete(previous) }
        expense.updatedAt = .now
        try context.save()
        if let previous, let store {
            store.remove(previous.fileName)
            store.remove(previous.thumbnailFileName)
        }
    }

    /// Deletes an expense, its receipt record (cascade) and the receipt files.
    public static func delete(_ expense: Expense, in context: ModelContext, store: ReceiptStore? = nil) throws {
        let files = expense.receipt.map { [$0.fileName, $0.thumbnailFileName] } ?? []
        context.delete(expense)
        try context.save()
        files.forEach { store?.remove($0) }
    }

    private static func attach(_ files: StoredReceiptFiles, to expense: Expense, in context: ModelContext) {
        let receipt = Receipt(
            fileName: files.fileName,
            fileTypeIdentifier: files.typeIdentifier,
            thumbnailFileName: files.thumbnailFileName,
            recognizedText: files.recognizedText
        )
        context.insert(receipt)
        expense.receipt = receipt
        if expense.status == .receiptPending { expense.status = .confirmed }
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
