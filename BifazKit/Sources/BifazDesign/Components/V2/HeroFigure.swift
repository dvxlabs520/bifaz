import SwiftUI

/// The big number of a screen: a data label above, the amount in hero size and a
/// small trend line at its trailing side (below it at accessibility text sizes).
/// VoiceOver reads label and amount as one element; the trend is decorative.
public struct HeroFigure: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let label: LocalizedStringResource
    private let amount: Decimal
    private let currencyCode: String
    private let trend: [Decimal]
    private let tint: Color

    public init(
        label: LocalizedStringResource,
        amount: Decimal,
        currencyCode: String = "EUR",
        trend: [Decimal],
        tint: Color = .bifazInk
    ) {
        self.label = label
        self.amount = amount
        self.currencyCode = currencyCode
        self.trend = trend
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            // Mono like the data labels, but as written (no capitals, no tracking): the
            // element reads label and amount, and the accessibility audit wants the
            // drawn text to match it (tracked capitals were reported as clipped).
            Text(label)
                .font(.bifazData)
                .foregroundStyle(Color.bifazInkSecondary)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BifazSpacing.xs) {
                    figure
                    sparkline
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: BifazSpacing.s) {
                    figure
                    Spacer(minLength: BifazSpacing.xs)
                    sparkline
                        .alignmentGuide(.lastTextBaseline) { $0[.bottom] }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    private var figure: some View {
        AmountView(amount, currencyCode: currencyCode, style: .hero, tint: tint)
    }

    private var sparkline: some View {
        TrendLine(points: trend, tint: tint)
            .frame(width: 96, height: 36)
    }

    private var accessibilityText: String {
        let value = amount.formatted(.currency(code: currencyCode).locale(locale))
        return LocalizedStringResource("heroFigure.accessibility \(label.resolved(in: locale)) \(value)", bundle: .module)
            .resolved(in: locale)
    }
}

#Preview("Light") {
    HeroFigureSamples()
}

#Preview("Dark") {
    HeroFigureSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    HeroFigureSamples().dynamicTypeSize(.accessibility3)
}

private struct HeroFigureSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xl) {
            HeroFigure(label: "budget.label", amount: 1284.50, trend: [20, 60, 90, 140, 130, 210, 320])
            HeroFigure(label: "budget.label", amount: 796.10, trend: [10, 10, 40, 90], tint: .bifazPro)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
        .environment(\.locale, Locale(identifier: "fr_FR"))
    }
}
