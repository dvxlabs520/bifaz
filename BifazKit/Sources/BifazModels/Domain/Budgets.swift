import Foundation
import SwiftData

/// Where a budget stands. Thresholds on spent / limit: below 80 % normal,
/// from 80 % near the limit, from 100 % over.
public enum BudgetState: Int, Sendable, Comparable, CaseIterable {
    case normal, nearLimit, over

    /// 0,80: "near the limit" starts here.
    public static let nearThreshold = Decimal(string: "0.80")!

    public init(spent: Decimal, limit: Decimal) {
        guard limit > 0 else {
            self = spent > 0 ? .over : .normal
            return
        }
        // Compare without dividing: spent ≥ 0,8 × limit, exactly to the cent.
        if spent >= limit {
            self = .over
        } else if spent >= limit * Self.nearThreshold {
            self = .nearLimit
        } else {
            self = .normal
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One budget for one month.
public struct BudgetStatus: Sendable, Equatable, Identifiable {
    public var budgetID: UUID
    public var categoryID: UUID
    public var space: Space
    public var limit: Decimal
    public var spent: Decimal
    /// Days left in the month, today included; `nil` for a past month.
    public var daysLeft: Int?

    public var id: UUID { budgetID }
    /// What is left (negative when over).
    public var remaining: Decimal { limit - spent }
    /// spent / limit (can pass 1).
    public var fraction: Decimal { limit > 0 ? spent / limit : 0 }
    public var state: BudgetState { BudgetState(spent: spent, limit: limit) }

    /// Spent in `month` per category, from Summary figures (one arithmetic with the Summary).
    public static func spentByCategory(_ figures: [ExpenseFigure], in month: DateInterval) -> [UUID: Decimal] {
        var spent: [UUID: Decimal] = [:]
        for figure in figures where month.containsHalfOpen(figure.date) {
            guard let id = figure.categoryID else { continue }
            spent[id, default: 0] += figure.amount
        }
        return spent
    }

    /// Days left in `month` counting today, or nil when `now` is not in it.
    public static func daysLeft(in month: DateInterval, now: Date, calendar: Calendar = .current) -> Int? {
        guard month.containsHalfOpen(now) else { return nil }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: month.end).day ?? 0
        return max(days, 1)
    }
}

/// A budget change the user should hear about right after saving an expense.
public struct BudgetAlert: Sendable, Equatable {
    public var categoryID: UUID
    public var state: BudgetState
    public var spent: Decimal
    public var limit: Decimal
}

public enum BudgetService {
    public enum ValidationError: Error, Equatable, Sendable {
        case amountNotPositive
        case amountTooLarge
    }

    /// Statuses of the budgets in the spaces of `space`, for `month`, from the
    /// Summary's figures. Largest share first.
    public static func statuses(
        _ budgets: [Budget],
        figures: [ExpenseFigure],
        month: DateInterval,
        space: SpaceFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [BudgetStatus] {
        let spent = BudgetStatus.spentByCategory(figures, in: month)
        let daysLeft = BudgetStatus.daysLeft(in: month, now: now, calendar: calendar)
        return budgets
            .compactMap { budget -> BudgetStatus? in
                guard let category = budget.category, space.includes(category.space) else { return nil }
                return BudgetStatus(
                    budgetID: budget.id, categoryID: category.id, space: category.space,
                    limit: budget.monthlyAmount, spent: spent[category.id] ?? 0, daysLeft: daysLeft
                )
            }
            .sorted { lhs, rhs in
                lhs.fraction != rhs.fraction ? lhs.fraction > rhs.fraction : lhs.budgetID.uuidString < rhs.budgetID.uuidString
            }
    }

    /// The status of `category`'s budget for the month containing `date`, if it has one.
    @MainActor
    public static func status(of category: ExpenseCategory, at date: Date, in context: ModelContext, now: Date = .now,
                              calendar: Calendar = .current) throws -> BudgetStatus? {
        guard let budget = category.budgets?.first else { return nil }
        let month = ExpenseGrouping.monthInterval(containing: date, calendar: calendar)
        let filter = ExpenseFilter(space: SpaceFilter(category.space), categoryIDs: [category.id], dateInterval: month)
        let spent = try filter.fetch(in: context).reduce(Decimal(0)) { $0 + $1.amountInEUR }
        return BudgetStatus(
            budgetID: budget.id, categoryID: category.id, space: category.space, limit: budget.monthlyAmount,
            spent: spent, daysLeft: BudgetStatus.daysLeft(in: month, now: now, calendar: calendar)
        )
    }

    /// The alert to show when a save moved a budget into a worse state (near the
    /// limit or over), or nil. `before` is the status before saving (nil = none).
    public static func alert(before: BudgetStatus?, after: BudgetStatus?) -> BudgetAlert? {
        guard let after, after.state != .normal, after.state > (before?.state ?? .normal) else { return nil }
        return BudgetAlert(categoryID: after.categoryID, state: after.state, spent: after.spent, limit: after.limit)
    }

    /// Creates the budget of `category`, or updates it: one budget per category.
    @discardableResult
    public static func setBudget(_ amount: Decimal, for category: ExpenseCategory, in context: ModelContext) throws -> Budget {
        let amount = amount.rounded(scale: 2)
        guard amount > 0 else { throw ValidationError.amountNotPositive }
        guard amount <= MoneyParser.maximum else { throw ValidationError.amountTooLarge }
        let existing = category.budgets ?? []
        let budget: Budget
        if let first = existing.first {
            budget = first
            budget.monthlyAmount = amount
            existing.dropFirst().forEach(context.delete)
        } else {
            budget = Budget(category: category, monthlyAmount: amount)
            context.insert(budget)
        }
        try context.save()
        return budget
    }

    public static func delete(_ budget: Budget, in context: ModelContext) throws {
        context.delete(budget)
        try context.save()
    }
}

extension BudgetService.ValidationError: LocalizedError {}

extension SpaceFilter {
    /// The filter that shows exactly one space.
    public init(_ space: Space) {
        self = space == .pro ? .pro : .personal
    }
}
