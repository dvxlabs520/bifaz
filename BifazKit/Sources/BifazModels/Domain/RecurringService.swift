import CryptoKit
import Foundation
import SwiftData

/// Recurring expenses without a backend (phase 4): the expenses due are
/// generated when the app opens or comes back to the foreground, catching up on
/// every missed occurrence.
///
/// Never twice: each rule remembers the last day it handled (`generatedThrough`),
/// so an expense the user deleted is not brought back; and each generated
/// expense gets an identifier derived from the rule and the day, so the same
/// occurrence generated on two devices is the same expense once synced.
public enum RecurringService {
    public enum ValidationError: Error, Equatable, Sendable {
        case amountNotPositive
        case endBeforeStart
        case foreignCurrency
    }

    /// The template of a rule, from an expense draft (amount, space, category,
    /// merchant, main VAT rate, client and project, note). Euros only.
    public struct Template: Equatable {
        public var draft: ExpenseDraft
        public var frequency: RecurrenceFrequency
        public var startDate: Date
        public var endDate: Date?

        public init(draft: ExpenseDraft, frequency: RecurrenceFrequency, startDate: Date, endDate: Date? = nil) {
            self.draft = draft
            self.frequency = frequency
            self.startDate = startDate
            self.endDate = endDate
        }

        /// The template of an existing rule (for editing).
        public init(rule: RecurringRule) {
            var draft = ExpenseDraft(
                amount: rule.amount, merchant: rule.merchant, space: rule.space, category: rule.category,
                vatRate: rule.vatRate.flatMap(VATRate.init(fraction:)), note: rule.note
            )
            draft.client = (rule.tags ?? []).first { $0.kind == .client }
            draft.project = (rule.tags ?? []).first { $0.kind == .project }
            self.init(draft: draft, frequency: rule.frequency, startDate: rule.startDate, endDate: rule.endDate)
        }

        /// A rule repeating a new expense: same values, first occurrence one period
        /// after the expense's date (the expense itself is today's occurrence).
        public static func repeating(_ draft: ExpenseDraft, frequency: RecurrenceFrequency,
                                     calendar: Calendar = .current) -> Template {
            let first = RecurrenceCalendar.occurrence(1, start: draft.date, frequency: frequency, calendar: calendar) ?? draft.date
            return Template(draft: draft, frequency: frequency, startDate: first)
        }

        public func validate(calendar: Calendar = .current) -> ValidationError? {
            guard let amount = draft.amount, amount > 0 else { return .amountNotPositive }
            if draft.isForeignCurrency { return .foreignCurrency }
            if let endDate, calendar.startOfDay(for: endDate) < calendar.startOfDay(for: startDate) { return .endBeforeStart }
            return nil
        }
    }

    // MARK: Rules

    @discardableResult
    public static func create(_ template: Template, in context: ModelContext, now: Date = .now, calendar: Calendar = .current,
                              saving: Bool = true) throws -> RecurringRule {
        if let error = template.validate(calendar: calendar) { throw error }
        let rule = RecurringRule(amount: 0, space: template.draft.space, frequency: template.frequency, nextDate: template.startDate)
        context.insert(rule)
        apply(template, to: rule, calendar: calendar)
        refreshNextDate(rule, now: now, calendar: calendar)
        if saving { try context.save() }
        return rule
    }

    /// Changes a rule. Only future occurrences change: expenses already generated
    /// keep their values, and occurrences already handled are not generated again.
    public static func update(_ rule: RecurringRule, with template: Template, in context: ModelContext, now: Date = .now,
                              calendar: Calendar = .current) throws {
        if let error = template.validate(calendar: calendar) { throw error }
        apply(template, to: rule, calendar: calendar)
        refreshNextDate(rule, now: now, calendar: calendar)
        try context.save()
    }

    /// Pausing skips the occurrences that fall while paused (they are not caught
    /// up when resumed): resuming marks everything up to yesterday as handled.
    public static func setPaused(_ rule: RecurringRule, _ paused: Bool, in context: ModelContext, now: Date = .now,
                                 calendar: Calendar = .current) throws {
        if !paused, !rule.isActive {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
            rule.generatedThrough = max(rule.generatedThrough ?? .distantPast, yesterday)
        }
        rule.isActive = !paused
        refreshNextDate(rule, now: now, calendar: calendar)
        try context.save()
    }

    /// Deletes the rule; the expenses it generated stay (they lose the link).
    public static func delete(_ rule: RecurringRule, in context: ModelContext) throws {
        context.delete(rule)
        try context.save()
    }

    private static func apply(_ template: Template, to rule: RecurringRule, calendar: Calendar) {
        let draft = template.draft
        rule.amount = (draft.amount ?? 0).rounded(scale: 2)
        rule.currencyCode = "EUR"
        rule.merchant = draft.normalizedMerchant
        rule.space = draft.space
        rule.category = draft.category
        rule.vatRate = draft.space == .pro ? draft.vatRate?.fraction : nil
        rule.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.tags = draft.space == .pro ? [draft.client, draft.project].compactMap { $0 } : []
        rule.frequency = template.frequency
        let start = calendar.startOfDay(for: template.startDate)
        if rule.startDate != start {
            rule.startDate = start
        }
        rule.endDate = template.endDate.map { calendar.startOfDay(for: $0) }
    }

    /// `nextDate` = the first occurrence not handled yet (from today on).
    static func refreshNextDate(_ rule: RecurringRule, now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        var from = today
        if let handled = rule.generatedThrough, let after = calendar.date(byAdding: .day, value: 1, to: handled) {
            from = max(from, after)
        }
        from = max(from, calendar.startOfDay(for: rule.startDate))
        rule.nextDate = RecurrenceCalendar.next(onOrAfter: from, start: rule.startDate, end: rule.endDate,
                                                frequency: rule.frequency, calendar: calendar) ?? .distantFuture
    }

    /// Average monthly cost of a rule.
    public static func monthlyEquivalent(of rule: RecurringRule) -> Decimal {
        RecurrenceCalendar.monthlyEquivalent(of: rule.amount, frequency: rule.frequency)
    }

    /// Whether the rule will produce no more expenses.
    public static func hasEnded(_ rule: RecurringRule) -> Bool { rule.nextDate == .distantFuture }

    // MARK: Generation

    /// Generates every expense due up to today (included) for every active rule,
    /// and returns them. Safe to call any number of times.
    @discardableResult
    public static func generateDue(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> [Expense] {
        let today = calendar.startOfDay(for: now)
        let rules = try context.fetch(FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.isActive }))
        var created: [Expense] = []
        for rule in rules {
            let from: Date
            if let handled = rule.generatedThrough {
                guard let next = calendar.date(byAdding: .day, value: 1, to: handled) else { continue }
                from = next
            } else {
                from = rule.startDate
            }
            let dates = RecurrenceCalendar.occurrences(
                start: rule.startDate, end: rule.endDate, frequency: rule.frequency,
                from: from, through: today, calendar: calendar
            )
            for date in dates {
                let id = expenseID(rule: rule.id, date: date, calendar: calendar)
                guard try !exists(id, in: context) else { continue }
                created.append(try generate(rule, on: date, id: id, in: context))
            }
            rule.generatedThrough = max(rule.generatedThrough ?? .distantPast, today)
            refreshNextDate(rule, now: now, calendar: calendar)
        }
        try context.save()
        return created
    }

    private static func generate(_ rule: RecurringRule, on date: Date, id: UUID, in context: ModelContext) throws -> Expense {
        var draft = ExpenseDraft(
            amount: rule.amount, merchant: rule.merchant,
            date: date.addingTimeInterval(12 * 3600), space: rule.space, category: rule.category,
            vatRate: rule.vatRate.flatMap(VATRate.init(fraction:)), note: rule.note
        )
        if let category = draft.category, category.space != draft.space { draft.category = nil }
        draft.source = .recurring
        draft.client = (rule.tags ?? []).first { $0.kind == .client }
        draft.project = (rule.tags ?? []).first { $0.kind == .project }
        let expense = try ExpenseService.create(from: draft, in: context, saving: false)
        expense.id = id
        expense.recurringRule = rule
        expense.recurrenceDate = date
        // A Pro expense needs its invoice; the bank does not send it.
        if rule.space == .pro { expense.status = .receiptPending }
        return expense
    }

    private static func exists(_ id: UUID, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetchCount(descriptor) > 0
    }

    /// The same rule and day always give the same identifier (on every device).
    public static func expenseID(rule: UUID, date: Date, calendar: Calendar) -> UUID {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let key = "\(rule.uuidString)|\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
        var bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5-like (name-based)
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

extension RecurringService.ValidationError: LocalizedError {}
