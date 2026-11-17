import Foundation

public extension Decimal {
    /// The value rounded to `scale` decimal places (half away from zero, like a till).
    func rounded(scale: Int = 2) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}

/// Turns what the user typed in an amount field into a `Decimal`.
///
/// Accepts the locale's decimal separator and also the other common one, so
/// "12,50", "12.50", "1 234,56", "1.234,56" and "1,234.56" all work in any
/// language. Strips currency symbols and spaces. Rejects negatives, more than
/// two decimals after rounding is applied, and anything that isn't a number.
public enum MoneyParser {
    /// Largest amount Bifaz accepts for a single expense.
    public static let maximum: Decimal = 10_000_000

    public static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        let allowed = Set("0123456789.,")
        let cleaned = text.filter { allowed.contains($0) }
        guard !cleaned.isEmpty, cleaned.contains(where: \.isNumber) else { return nil }
        // A minus sign anywhere means a negative amount, which an expense can't be.
        guard !text.contains("-"), !text.contains("−") else { return nil }

        let separators = cleaned.indices.filter { cleaned[$0] == "," || cleaned[$0] == "." }
        var normalized = cleaned
        if let last = separators.last {
            let decimals = cleaned.distance(from: last, to: cleaned.endIndex) - 1
            let lastChar = cleaned[last]
            let sameCount = cleaned.filter { $0 == lastChar }.count
            // "1.234" or "1,234,567" (one kind, groups of 3, repeated or not
            // the locale's decimal separator) is a grouping separator.
            let localeDecimal = locale.decimalSeparator ?? ","
            let integerPart = cleaned[..<last].filter(\.isNumber)
            let isGrouping = decimals == 3
                && integerPart != "0" // "0,005" is never a thousands group
                && (sameCount > 1 || (separators.count == 1 && String(lastChar) != localeDecimal))
            normalized = cleaned.filter { $0 != "," && $0 != "." }
            if !isGrouping {
                let integerDigits = cleaned[..<last].filter(\.isNumber)
                let fraction = cleaned[cleaned.index(after: last)...].filter(\.isNumber)
                normalized = String(integerDigits) + "." + String(fraction)
            }
        }
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        let rounded = value.rounded(scale: 2)
        guard rounded <= maximum else { return nil }
        return rounded
    }
}
