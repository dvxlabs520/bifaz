import SwiftUI

/// A monetary amount formatted for the current locale (`1 284,50 €` in French,
/// `€1,284.50` in English), in tabular figures. Shrinks before it truncates.
/// Hero and medium amounts dim their decimals (v2): the whole part in the tint,
/// the decimal separator and cents in secondary ink, digits animated on change.
public struct AmountView: View {
    /// Size of the amount.
    public enum Style: Sendable {
        /// Hero amount, e.g. the month total.
        case hero
        /// Amount on a card.
        case medium
        /// Amount in a list row.
        case row
    }

    @Environment(\.locale) private var locale

    private let amount: Decimal
    private let currencyCode: String
    private let style: Style
    private let tint: Color

    public init(_ amount: Decimal, currencyCode: String = "EUR", style: Style = .row, tint: Color = .bifazInk) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.style = style
        self.tint = tint
    }

    private var formatted: String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }

    private var font: Font {
        switch style {
        case .hero: .bifazAmountHero
        case .medium: .bifazAmountMedium
        case .row: .bifazAmount
        }
    }

    private var dimsDecimals: Bool { style != .row }

    public var body: some View {
        Group {
            if dimsDecimals {
                let parts = AmountParts(formatted: formatted, decimalSeparator: locale.decimalSeparator ?? ".")
                Text("\(Text(verbatim: parts.whole).foregroundStyle(tint))\(Text(verbatim: parts.decimals).foregroundStyle(Color.bifazInkSecondary))\(Text(verbatim: parts.suffix).foregroundStyle(tint))")
            } else {
                Text(verbatim: formatted).foregroundStyle(tint)
            }
        }
        .font(font)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText(value: NSDecimalNumber(decimal: amount).doubleValue))
        .accessibilityLabel(formatted)
    }
}

/// A formatted amount cut where the cents start: `1 284` · `,50` · ` €`,
/// `€1,284` · `.50` · ``, `¥1,280` · `` · `` (no decimals).
public struct AmountParts: Equatable, Sendable {
    public var whole: String
    /// Decimal separator and the digits after it.
    public var decimals: String
    /// What follows the cents (a currency symbol after the number).
    public var suffix: String

    public init(whole: String, decimals: String, suffix: String) {
        self.whole = whole
        self.decimals = decimals
        self.suffix = suffix
    }

    public init(formatted: String, decimalSeparator: String) {
        guard !decimalSeparator.isEmpty, let range = formatted.range(of: decimalSeparator, options: .backwards) else {
            self.whole = formatted
            self.decimals = ""
            self.suffix = ""
            return
        }
        let after = formatted[range.upperBound...]
        let digits = after.prefix { $0.isNumber }
        // A separator not followed by digits is not a decimal point.
        guard !digits.isEmpty else {
            self.whole = formatted
            self.decimals = ""
            self.suffix = ""
            return
        }
        self.whole = String(formatted[..<range.lowerBound])
        self.decimals = decimalSeparator + digits
        self.suffix = String(after.dropFirst(digits.count))
    }
}

#Preview("Light") {
    AmountViewSamples()
}

#Preview("Dark") {
    AmountViewSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    AmountViewSamples().dynamicTypeSize(.accessibility3)
}

private struct AmountViewSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.m) {
            AmountView(1284.50, style: .hero)
            AmountView(796.10, style: .medium, tint: .bifazPro)
            AmountView(42.80, style: .row)
            AmountView(1284.50, style: .row)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
