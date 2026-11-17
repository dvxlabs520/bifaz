import SwiftUI

/// A budget progress bar: green below 80 %, amber from 80 to 100 %, red above.
/// The fill is capped at 100 %. State is always shown with an icon and a word
/// as well as colour.
public struct BudgetBar: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var barHeight: CGFloat = 8

    private let spent: Decimal
    private let limit: Decimal
    private let currencyCode: String

    public init(spent: Decimal, limit: Decimal, currencyCode: String = "EUR") {
        self.spent = spent
        self.limit = limit
        self.currencyCode = currencyCode
    }

    private enum Status {
        case onTrack, closeToLimit, overBudget

        var color: Color {
            switch self {
            case .onTrack: .bifazSuccess
            case .closeToLimit: .bifazWarning
            case .overBudget: .bifazError
            }
        }

        var symbolName: String {
            switch self {
            case .onTrack: "checkmark.circle.fill"
            case .closeToLimit: "exclamationmark.triangle.fill"
            case .overBudget: "xmark.octagon.fill"
            }
        }

        var title: LocalizedStringResource {
            switch self {
            case .onTrack: LocalizedStringResource("budget.status.onTrack", bundle: .module)
            case .closeToLimit: LocalizedStringResource("budget.status.closeToLimit", bundle: .module)
            case .overBudget: LocalizedStringResource("budget.status.overBudget", bundle: .module)
            }
        }
    }

    /// Share of the limit already spent. With no limit, any spending counts as over.
    private var ratio: Double {
        guard limit > 0 else { return spent > 0 ? 1.01 : 0 }
        return Double(truncating: (spent / limit) as NSDecimalNumber)
    }

    private var status: Status {
        switch ratio {
        case ..<0.8: .onTrack
        case ...1: .closeToLimit
        default: .overBudget
        }
    }

    private var progressText: String {
        let spentText = spent.formatted(.currency(code: currencyCode).locale(locale))
        let limitText = limit.formatted(.currency(code: currencyCode).locale(locale))
        return LocalizedStringResource("budget.progress \(spentText) \(limitText)", bundle: .module)
            .resolved(in: locale)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            Capsule()
                .fill(Color.bifazHairline)
                .frame(height: barHeight)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(status.color)
                            .frame(width: proxy.size.width * min(ratio, 1))
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: ratio)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BifazSpacing.xxs) { progress; statusLabel }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    progress
                    Spacer(minLength: BifazSpacing.xs)
                    statusLabel
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("budget.label", bundle: .module))
        .accessibilityValue(accessibilityValueText)
    }

    private var progress: some View {
        Text(verbatim: progressText)
            .font(.bifazCaption)
            .foregroundStyle(Color.bifazInkSecondary)
    }

    private var statusLabel: some View {
        HStack(spacing: BifazSpacing.xxs) {
            Image(systemName: status.symbolName)
            Text(status.title)
        }
        .font(.bifazLabel)
        .foregroundStyle(status.color)
    }

    private var accessibilityValueText: String {
        let percent = ratio.formatted(.percent.precision(.fractionLength(0)).locale(locale))
        return LocalizedStringResource(
            "budget.accessibility.value \(percent) \(progressText) \(status.title.resolved(in: locale))",
            bundle: .module
        ).resolved(in: locale)
    }
}

#Preview("Light") {
    BudgetBarSamples()
}

#Preview("Dark") {
    BudgetBarSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    BudgetBarSamples().dynamicTypeSize(.accessibility3)
}

private struct BudgetBarSamples: View {
    var body: some View {
        VStack(spacing: BifazSpacing.l) {
            BudgetBar(spent: 120, limit: 300)
            BudgetBar(spent: 255, limit: 300)
            BudgetBar(spent: 342.50, limit: 300)
            BudgetBar(spent: 0, limit: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bifazPaper)
    }
}
