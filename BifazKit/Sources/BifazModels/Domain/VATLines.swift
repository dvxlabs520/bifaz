import Foundation
import SwiftData

/// One VAT line as a value: `base` (HT) + `vat` = `total` (TTC), all to the cent.
///
/// **Rounding rule** (schema v2, phase 3):
/// 1. Every amount is in cents. A computed VAT is `total − total / (1 + rate)`
///    rounded half up to the cent (`VATCalculator`); the base is then
///    `total − vat`, so `base + vat == total` holds exactly on every line.
/// 2. The lines of an expense add up to its amount exactly. With two rates typed
///    by hand, the main rate takes the remainder (`amount − other part`).
/// 3. Printed lines (from a receipt) keep their printed VAT. If their totals miss
///    the receipt total by at most one cent per line (rounding on the receipt),
///    the gap goes to the base of the largest line. A larger positive gap is a
///    part without VAT (tip, deposit) and becomes a 0 % line. Lines that add up
///    to more than the total are a misread: the whole amount is taxed at the
///    rate of the largest printed line instead.
public struct VATPart: Equatable, Hashable, Sendable {
    /// Rate as a fraction; `nil` only for v1 expenses with several rates (see `ExpenseVATLine`).
    public var rate: Decimal?
    public var base: Decimal
    public var vat: Decimal
    public var total: Decimal

    public init(rate: Decimal?, base: Decimal, vat: Decimal, total: Decimal) {
        self.rate = rate
        self.base = base
        self.vat = vat
        self.total = total
    }

    /// `total` (TTC) taxed at `rate`, with the VAT computed (rule 1).
    public static func computed(total: Decimal, rate: Decimal) -> VATPart {
        let total = total.rounded(scale: 2)
        let vat = VATCalculator.vatAmount(includedIn: total, rate: rate)
        return VATPart(rate: rate, base: total - vat, vat: vat, total: total)
    }

    public init(_ line: ExpenseVATLine) {
        self.init(rate: line.rate, base: line.base, vat: line.vat, total: line.total)
    }

    /// The French rate of this line, if it is one.
    public var frenchRate: VATRate? { rate.flatMap(VATRate.init(fraction:)) }

    /// Base and VAT are not negative and add up to the total.
    var isWellFormed: Bool { base >= 0 && vat >= 0 && base + vat == total }
}

/// A VAT line as printed on a receipt. The reader fills what it found.
public struct PrintedVATLine: Equatable, Sendable {
    public var rate: Decimal
    public var base: Decimal?
    public var vat: Decimal?

    public init(rate: Decimal, base: Decimal? = nil, vat: Decimal? = nil) {
        self.rate = rate
        self.base = base
        self.vat = vat
    }
}

public enum VATBreakdown {
    /// Sorted for display and storage: largest total first, then by rate.
    public static func sorted(_ parts: [VATPart]) -> [VATPart] {
        parts.sorted { lhs, rhs in
            lhs.total != rhs.total ? lhs.total > rhs.total : (lhs.rate ?? -1) > (rhs.rate ?? -1)
        }
    }

    /// Every line is well formed and the totals add up to `amount`.
    public static func isConsistent(_ parts: [VATPart], amount: Decimal) -> Bool {
        parts.allSatisfy(\.isWellFormed) && parts.reduce(0) { $0 + $1.total } == amount.rounded(scale: 2)
    }

    /// Lines for a receipt total from what was printed (rounding rule 3).
    /// Empty when there is nothing to work with.
    public static func lines(fromPrinted printed: [PrintedVATLine], total: Decimal) -> [VATPart] {
        let total = total.rounded(scale: 2)
        let usable = printed.filter { $0.rate >= 0 && $0.rate < 1 }
        guard total > 0, !usable.isEmpty else { return [] }
        let fallback = [VATPart.computed(total: total, rate: mainRate(of: usable))]

        // Lines with amounts become parts; at most one line without amounts takes the rest.
        var parts: [VATPart] = []
        var withoutAmounts: [Decimal] = []
        for line in usable {
            if let part = part(from: line) {
                parts.append(part)
            } else {
                withoutAmounts.append(line.rate)
            }
        }
        if parts.isEmpty || withoutAmounts.count > 1 { return fallback }
        parts = merged(parts)
        let printedSum = parts.reduce(0) { $0 + $1.total }
        if let rate = withoutAmounts.first {
            guard printedSum < total else { return fallback }
            parts = merged(parts + [.computed(total: total - printedSum, rate: rate)])
        }

        let gap = total - parts.reduce(0) { $0 + $1.total }
        let tolerance = Decimal(string: "0.01")! * Decimal(parts.count)
        if gap != 0 {
            if abs(gap) <= tolerance {
                let index = parts.indices.max { parts[$0].total < parts[$1].total }!
                parts[index].base += gap
                parts[index].total += gap
            } else if gap > 0 {
                parts = merged(parts + [VATPart(rate: 0, base: gap, vat: 0, total: gap)])
            } else {
                return fallback
            }
        }
        guard isConsistent(parts, amount: total) else { return fallback }
        return sorted(parts)
    }

    /// A printed line with amounts, or nil when it has none.
    private static func part(from line: PrintedVATLine) -> VATPart? {
        let base = line.base?.rounded(scale: 2)
        let vat = line.vat?.rounded(scale: 2)
        switch (base, vat) {
        case let (base?, vat?):
            return VATPart(rate: line.rate, base: base, vat: vat, total: base + vat)
        case let (base?, nil):
            let vat = (base * line.rate).rounded(scale: 2)
            return VATPart(rate: line.rate, base: base, vat: vat, total: base + vat)
        case let (nil, vat?) where line.rate > 0:
            let base = (vat / line.rate).rounded(scale: 2)
            return VATPart(rate: line.rate, base: base, vat: vat, total: base + vat)
        default:
            return nil
        }
    }

    /// Adds up lines with the same rate.
    private static func merged(_ parts: [VATPart]) -> [VATPart] {
        var result: [VATPart] = []
        for part in parts {
            if let index = result.firstIndex(where: { $0.rate == part.rate }) {
                result[index].base += part.base
                result[index].vat += part.vat
                result[index].total += part.total
            } else {
                result.append(part)
            }
        }
        return result
    }

    /// The rate of the largest printed line (by base, then VAT), else the highest rate.
    private static func mainRate(of lines: [PrintedVATLine]) -> Decimal {
        let sized = lines.compactMap { line in part(from: line).map { (line.rate, $0.total) } }
        if let largest = sized.max(by: { $0.1 < $1.1 }) { return largest.0 }
        return lines.map(\.rate).max() ?? 0
    }
}

// MARK: - Migration from schema v1

/// Creates the VAT line of every expense migrated from schema v1.
///
/// Version 1 stored one rate and the total VAT. With a single rate the VAT equals
/// the computed one and the line gets that rate. A receipt with several rates
/// stored the main rate and the printed total VAT, which no single rate explains:
/// the line keeps that VAT with no rate (`nil`), so no amount changes and the
/// split is not invented. Amounts, rates and dates of the expenses are not touched.
enum VATMigration {
    // Pinned to the version-2 classes: this stage runs inside the v1 → v2 step,
    // whatever the current version is.
    typealias V2Expense = BifazSchemaV2.Expense
    typealias V2Line = BifazSchemaV2.ExpenseVATLine

    static func createLines(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<V2Expense>(predicate: #Predicate { $0.vatRate != nil || $0.vatAmount != nil })
        for expense in try context.fetch(descriptor) where (expense.vatLines ?? []).isEmpty {
            guard let part = part(amount: expense.amount, vatRate: expense.vatRate, vatAmount: expense.vatAmount) else { continue }
            let line = V2Line(rate: part.rate, base: part.base, vat: part.vat, total: part.total)
            context.insert(line)
            line.expense = expense
            if expense.vatAmount == nil { expense.vatAmount = part.vat }
        }
        try context.save()
    }

    static func part(amount: Decimal, vatRate: Decimal?, vatAmount: Decimal?) -> VATPart? {
        guard amount > 0 else { return nil }
        var rate = vatRate
        let vat: Decimal
        if let storedRate = vatRate {
            let computed = VATCalculator.vatAmount(includedIn: amount, rate: storedRate)
            vat = vatAmount ?? computed
            if abs(vat - computed) > Decimal(string: "0.01")! { rate = nil }
        } else if let stored = vatAmount {
            vat = stored
        } else {
            return nil
        }
        guard vat >= 0, vat <= amount else { return nil }
        return VATPart(rate: rate, base: amount - vat, vat: vat, total: amount)
    }
}
