import SwiftUI
import BifazModels

/// Two thin capsules whose widths follow the Pro and Personal amounts, with a
/// legend underneath that names each space with its symbol and amount (never
/// colour alone). With no spending it shows a single quiet track.
public struct SpaceSplitBar: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var barHeight: CGFloat = 5

    private let pro: Decimal
    private let personal: Decimal
    private let currencyCode: String
    private let showsLegend: Bool
    private let gap: CGFloat = 3

    public init(pro: Decimal, personal: Decimal, currencyCode: String = "EUR", showsLegend: Bool = true) {
        self.pro = max(pro, 0)
        self.personal = max(personal, 0)
        self.currencyCode = currencyCode
        self.showsLegend = showsLegend
    }

    private var total: Decimal { pro + personal }

    private var proShare: Double {
        total > 0 ? Double(truncating: (pro / total) as NSDecimalNumber) : 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            bar
            if showsLegend, total > 0 {
                legend
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var bar: some View {
        GeometryReader { proxy in
            if total > 0 {
                let available = proxy.size.width - (pro > 0 && personal > 0 ? gap : 0)
                HStack(spacing: gap) {
                    if pro > 0 {
                        Capsule().fill(Color.bifazPro).frame(width: available * proShare)
                    }
                    if personal > 0 {
                        Capsule().fill(Color.bifazPersonal).frame(width: available * (1 - proShare))
                    }
                }
            } else {
                Capsule().fill(Color.bifazSurfaceMuted)
            }
        }
        .frame(height: barHeight)
    }

    @ViewBuilder
    private var legend: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
                legendItem(.pro, amount: pro)
                legendItem(.personal, amount: personal)
            }
        } else {
            HStack {
                legendItem(.pro, amount: pro)
                Spacer(minLength: BifazSpacing.xs)
                legendItem(.personal, amount: personal)
            }
        }
    }

    private func legendItem(_ space: Space, amount: Decimal) -> some View {
        HStack(spacing: BifazSpacing.xxs) {
            BifazIconView(space.icon, size: 14, relativeTo: .caption)
                .foregroundStyle(space.color)
            Text(verbatim: legendText(space, amount: amount))
                .foregroundStyle(Color.bifazInkSecondary)
        }
        .font(.bifazCaption)
    }

    private func formatted(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }

    private func legendText(_ space: Space, amount: Decimal) -> String {
        let name = space.title.resolved(in: locale)
        let value = formatted(amount)
        return LocalizedStringResource("spaceSplit.legend \(name) \(value)", bundle: .module).resolved(in: locale)
    }

    private var accessibilityText: String {
        guard total > 0 else {
            return LocalizedStringResource("spaceSplit.empty", bundle: .module).resolved(in: locale)
        }
        func percent(_ share: Double) -> String {
            share.formatted(.percent.precision(.fractionLength(0)).locale(locale))
        }
        let proName = Space.pro.title.resolved(in: locale)
        let personalName = Space.personal.title.resolved(in: locale)
        let proPercent = percent(proShare), personalPercent = percent(1 - proShare)
        let proAmount = formatted(pro), personalAmount = formatted(personal)
        return LocalizedStringResource(
            "spaceSplit.accessibility \(proName) \(proPercent) \(proAmount) \(personalName) \(personalPercent) \(personalAmount)",
            bundle: .module
        ).resolved(in: locale)
    }
}

#Preview("Light") {
    SpaceSplitBarSamples()
}

#Preview("Dark") {
    SpaceSplitBarSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    SpaceSplitBarSamples().dynamicTypeSize(.accessibility3)
}

private struct SpaceSplitBarSamples: View {
    var body: some View {
        VStack(spacing: BifazSpacing.xl) {
            SpaceSplitBar(pro: 796.10, personal: 488.40)
            SpaceSplitBar(pro: 120, personal: 0)
            SpaceSplitBar(pro: 796.10, personal: 488.40, showsLegend: false)
            SpaceSplitBar(pro: 0, personal: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
