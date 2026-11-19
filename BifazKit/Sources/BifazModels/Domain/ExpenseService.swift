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
        in context: ModelContext,
        saving: Bool = true
    ) throws -> Expense {
        if let error = draft.validate() { throw error }
        let expense = Expense(amount: 0, space: draft.space, source: draft.source)
        context.insert(expense)
        apply(draft, to: expense, in: context)
        if let receipt { attach(receipt, to: expense, in: context) }
        MerchantMemory.remember(expense, in: context)
        if saving { try context.save() }
        return expense
    }

    /// Saves a new expense and, with `frequency`, a rule repeating it from the next
    /// period — all or nothing: both are validated before anything is inserted, and
    /// saved together; if the save fails, the context is rolled back, so neither the
    /// expense nor the rule stays and saving again cannot duplicate the expense (the
    /// caller removes the receipt files it stored).
    @discardableResult
    public static func create(
        from draft: ExpenseDraft,
        receipt: StoredReceiptFiles? = nil,
        repeating frequency: RecurrenceFrequency?,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> (expense: Expense, rule: RecurringRule?) {
        if let error = draft.validate() { throw error }
        let template = frequency.map { RecurringService.Template.repeating(draft, frequency: $0, calendar: calendar) }
        if let error = template?.validate(calendar: calendar) { throw error }
        do {
            let expense = try create(from: draft, receipt: receipt, in: context, saving: false)
            let rule = try template.map { try RecurringService.create($0, in: context, now: now, calendar: calendar, saving: false) }
            try context.save()
            return (expense, rule)
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Applies an edited draft to an existing expense. `saving: false` leaves the
    /// save to the caller (bulk inserts of generated data).
    public static func update(_ expense: Expense, with draft: ExpenseDraft, in context: ModelContext, saving: Bool = true) throws {
        if let error = draft.validate() { throw error }
        apply(draft, to: expense, in: context)
        expense.updatedAt = .now
        MerchantMemory.remember(expense, in: context)
        if saving { try context.save() }
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

    /// Replaces the VAT lines when they changed, and keeps `vatRate` (main line)
    /// and `vatAmount` (sum) in step with them.
    static func setVATLines(_ parts: [VATPart], on expense: Expense, in context: ModelContext) {
        let parts = VATBreakdown.sorted(parts)
        guard expense.sortedVATLines.map(VATPart.init) != parts else { return }
        for line in expense.vatLines ?? [] { context.delete(line) }
        expense.vatLines = []
        for (index, part) in parts.enumerated() {
            let line = ExpenseVATLine(rate: part.rate, base: part.base, vat: part.vat, total: part.total, sortOrder: index)
            context.insert(line)
            line.expense = expense
        }
        expense.vatRate = parts.first?.rate
        expense.vatAmount = parts.isEmpty ? nil : parts.reduce(0) { $0 + $1.vat }
    }

    private static func apply(_ draft: ExpenseDraft, to expense: Expense, in context: ModelContext) {
        let amount = (draft.amount ?? 0).rounded(scale: 2)
        expense.amount = amount
        expense.currencyCode = draft.currencyCode
        expense.amountInEUR = draft.amountInEUR ?? amount
        if let quote = draft.effectiveExchangeRate {
            // Fixed now, never recalculated.
            expense.exchangeRate = quote.rate
            expense.exchangeRateDate = quote.date
            expense.exchangeRateSourceRawValue = quote.source.rawValue
        } else {
            expense.exchangeRate = nil
            expense.exchangeRateDate = nil
            expense.exchangeRateSourceRawValue = nil
        }
        // Client and project exist only in Pro.
        expense.tags = draft.space == .pro ? [draft.client, draft.project].compactMap { $0 } : []
        expense.merchant = draft.normalizedMerchant
        expense.date = draft.date
        expense.space = draft.space
        expense.category = draft.category
        setVATLines(draft.vatLines, on: expense, in: context)
        expense.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ExpenseDraft.ValidationError: LocalizedError {}
