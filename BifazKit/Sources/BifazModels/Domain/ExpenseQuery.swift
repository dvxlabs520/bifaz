import Foundation
import SwiftData

/// Everything the history screen can filter by. Space and date run in the
/// store (predicate); search and category run in memory on that result.
public struct ExpenseFilter: Equatable, Sendable {
    public var space: SpaceFilter
    /// Categories to keep (by `ExpenseCategory.id`); empty = all (unless `withoutCategory`).
    public var categoryIDs: Set<UUID>
    /// Keep expenses with no category (with `categoryIDs`, either one matches).
    public var withoutCategory: Bool
    /// Client and project tags the expense must all carry (phase 4); empty = any.
    public var tagIDs: Set<UUID>
    /// Inclusive start and exclusive end; `nil` = all time.
    public var dateInterval: DateInterval?
    public var onlyReceiptPending: Bool
    public var searchText: String

    public init(
        space: SpaceFilter = .all,
        categoryIDs: Set<UUID> = [],
        withoutCategory: Bool = false,
        tagIDs: Set<UUID> = [],
        dateInterval: DateInterval? = nil,
        onlyReceiptPending: Bool = false,
        searchText: String = ""
    ) {
        self.space = space
        self.categoryIDs = categoryIDs
        self.withoutCategory = withoutCategory
        self.tagIDs = tagIDs
        self.dateInterval = dateInterval
        self.onlyReceiptPending = onlyReceiptPending
        self.searchText = searchText
    }

    /// Filters other than space and search are active (for the filter badge).
    public var activeRefinementCount: Int {
        (categoryIDs.isEmpty && !withoutCategory ? 0 : 1) + (tagIDs.isEmpty ? 0 : 1) + (dateInterval == nil ? 0 : 1) + (onlyReceiptPending ? 1 : 0)
    }

    /// Fetch descriptor for the store-side part (space, dates, pending receipts), newest first.
    public var fetchDescriptor: FetchDescriptor<Expense> {
        let spaceRaw = space.space?.rawValue ?? ""
        let start = dateInterval?.start ?? .distantPast
        let end = dateInterval?.end ?? .distantFuture
        let statusRaw = onlyReceiptPending ? ExpenseStatus.receiptPending.rawValue : ""
        let predicate = #Predicate<Expense> { expense in
            (spaceRaw == "" || expense.spaceRawValue == spaceRaw)
                && (statusRaw == "" || expense.statusRawValue == statusRaw)
                && expense.date >= start && expense.date < end
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [
            SortDescriptor(\.date, order: .reverse),
            SortDescriptor(\.createdAt, order: .reverse),
        ])
        // Rows show the category name and icon: fetch it with the expenses.
        descriptor.relationshipKeyPathsForPrefetching = [\.category]
        return descriptor
    }

    /// The in-memory part: categories and text search (pending receipts are
    /// re-checked so the function is also correct on its own).
    /// `categoryName` resolves the shown name (built-in categories are translated).
    public func matches(_ expense: Expense, categoryName: (ExpenseCategory) -> String = { $0.name }) -> Bool {
        if !categoryIDs.isEmpty || withoutCategory {
            if let id = expense.category?.id {
                guard categoryIDs.contains(id) else { return false }
            } else {
                guard withoutCategory else { return false }
            }
        }
        if onlyReceiptPending, expense.status != .receiptPending { return false }
        if !tagIDs.isEmpty {
            let carried = Set((expense.tags ?? []).map(\.id))
            guard tagIDs.isSubset(of: carried) else { return false }
        }
        let query = Self.fold(searchText)
        guard !query.isEmpty else { return true }
        let haystack = [expense.merchant, expense.note, expense.category.map(categoryName) ?? ""].map(Self.fold)
        return query.split(separator: " ").allSatisfy { term in
            haystack.contains { $0.contains(term) }
        }
    }

    /// Runs the full filter against a context.
    public func fetch(in context: ModelContext, categoryName: (ExpenseCategory) -> String = { $0.name }) throws -> [Expense] {
        try context.fetch(fetchDescriptor).filter { matches($0, categoryName: categoryName) }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Sums used by Summary and the history headers.
public struct ExpenseTotals: Equatable, Sendable {
    public var total: Decimal = 0
    public var pro: Decimal = 0
    public var personal: Decimal = 0
    /// VAT on Pro expenses.
    public var proVAT: Decimal = 0
    public var count: Int = 0

    public init() {}

    public init(_ expenses: some Sequence<Expense>) {
        for expense in expenses {
            add(expense.amountInEUR, space: expense.space, vat: expense.vatAmountInEUR ?? 0)
        }
    }

    /// The same sums from Summary figures (one arithmetic for both).
    public init(figures: some Sequence<ExpenseFigure>) {
        for figure in figures {
            add(figure.amount, space: figure.space, vat: figure.vatLines.reduce(0) { $0 + $1.vat })
        }
    }

    private mutating func add(_ amount: Decimal, space: Space, vat: Decimal) {
        total += amount
        count += 1
        switch space {
        case .pro:
            pro += amount
            proVAT += vat
        case .personal:
            personal += amount
        }
    }
}

/// One month of expenses for the history list.
public struct MonthGroup: Identifiable {
    /// First instant of the month.
    public let month: Date
    public let expenses: [Expense]
    public let totals: ExpenseTotals

    public var id: Date { month }
}

/// One day of expenses for the v2 history ("Yesterday · €93.00").
public struct DayGroup: Identifiable {
    /// First instant of the day.
    public let day: Date
    public let expenses: [Expense]
    public let totals: ExpenseTotals

    public var id: Date { day }
}

public enum ExpenseGrouping {
    /// Groups expenses (any order) by calendar month, newest month first,
    /// keeping the incoming order inside each month.
    public static func byMonth(_ expenses: [Expense], calendar: Calendar = .current) -> [MonthGroup] {
        var buckets: [Date: [Expense]] = [:]
        var order: [Date] = []
        for expense in expenses {
            let month = calendar.dateInterval(of: .month, for: expense.date)?.start ?? expense.date
            if buckets[month] == nil { order.append(month) }
            buckets[month, default: []].append(expense)
        }
        return order.sorted(by: >).map { month in
            let items = buckets[month] ?? []
            return MonthGroup(month: month, expenses: items, totals: ExpenseTotals(items))
        }
    }

    /// Groups expenses (any order) by calendar day, newest day first, newest
    /// expense first inside a day, with each day's totals (v2 history).
    public static func byDay(_ expenses: [Expense], calendar: Calendar = .current) -> [DayGroup] {
        var buckets: [Date: [Expense]] = [:]
        for expense in expenses {
            buckets[calendar.startOfDay(for: expense.date), default: []].append(expense)
        }
        return buckets.keys.sorted(by: >).map { day in
            let items = (buckets[day] ?? []).sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
            return DayGroup(day: day, expenses: items, totals: ExpenseTotals(items))
        }
    }

    /// The calendar month containing `date`.
    public static func monthInterval(containing date: Date = .now, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }
}
