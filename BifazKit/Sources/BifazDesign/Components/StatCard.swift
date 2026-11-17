import SwiftUI

/// A card with a title, a medium amount and an optional detail line,
/// read by VoiceOver as one element.
public struct StatCard: View {
    private let title: LocalizedStringResource
    private let amount: Decimal
    private let currencyCode: String
    private let detail: LocalizedStringResource?
    private let accent: Color

    public init(
        title: LocalizedStringResource,
        amount: Decimal,
        currencyCode: String = "EUR",
        detail: LocalizedStringResource? = nil,
        accent: Color = .bifazInk
    ) {
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.detail = detail
        self.accent = accent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            Text(title)
                .font(.bifazSubheadline)
                .foregroundStyle(Color.bifazInkSecondary)
            AmountView(amount, currencyCode: currencyCode, style: .medium, tint: accent)
            if let detail {
                Text(detail)
                    .font(.bifazCaption)
                    .foregroundStyle(Color.bifazInkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bifazCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    StatCardSamples()
}

#Preview("Dark") {
    StatCardSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    StatCardSamples().dynamicTypeSize(.accessibility3)
}

private struct StatCardSamples: View {
    var body: some View {
        VStack(spacing: BifazSpacing.m) {
            StatCard(
                title: "Pro this month",
                amount: 1234.50,
                detail: "12 expenses",
                accent: .bifazPro
            )
            StatCard(
                title: "Personal this month",
                amount: 486.20,
                accent: .bifazPersonal
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bifazPaper)
    }
}
