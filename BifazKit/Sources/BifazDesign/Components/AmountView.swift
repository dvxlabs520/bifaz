import SwiftUI

/// A monetary amount formatted for the current locale (`1 234,50 €` in French,
/// `€1,234.50` in English), in tabular figures. Shrinks before it truncates.
public struct AmountView: View {
    /// Size of the amount.
    public enum Style: Sendable {
        /// Hero amount, e.g. the month total.
        case large
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
        case .large: .bifazAmountLarge
        case .medium: .bifazAmountMedium
        case .row: .bifazAmount
        }
    }

    public var body: some View {
        Text(verbatim: formatted)
            .font(font)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityLabel(formatted)
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
            AmountView(1234.50, style: .large)
            AmountView(86.20, style: .medium, tint: .bifazPro)
            AmountView(4.30, style: .row)
            AmountView(1234.50, style: .row)
                .environment(\.locale, Locale(identifier: "en"))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
