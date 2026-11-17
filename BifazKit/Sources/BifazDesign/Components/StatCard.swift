import SwiftUI

/// A bordered card with a caption, an amount and an optional detail line, e.g.
/// "Pro this month". Reads as one element for VoiceOver.
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
                .font(.bifazCaption)
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
            HStack(spacing: BifazSpacing.s) {
                StatCard(title: "Pro", amount: 796.10, accent: .bifazPro)
                StatCard(title: "Perso", amount: 488.40, accent: .bifazPersonal)
            }
            StatCard(title: "Dépensé en novembre", amount: 1284.50, detail: "12 dépenses chez Monoprix, SNCF, Adobe")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
