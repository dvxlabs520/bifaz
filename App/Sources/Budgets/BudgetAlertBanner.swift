import SwiftUI
import BifazModels
import BifazDesign

/// A compact in-app banner shown after saving an expense that pushes a budget to
/// 80 % or beyond. The parent decides when to show it, for how long, and posts
/// the VoiceOver announcement (the label here is complete).
struct BudgetAlertBanner: View {
    @Environment(\.locale) private var locale

    private let alert: BudgetAlert
    private let categoryName: String
    private let onDismiss: () -> Void

    init(alert: BudgetAlert, categoryName: String, onDismiss: @escaping () -> Void) {
        self.alert = alert
        self.categoryName = categoryName
        self.onDismiss = onDismiss
    }

    private var tint: Color { alert.state == .over ? .bifazErrorTint : .bifazWarningTint }

    /// Whole percent of the limit used, rounded down so 99,6 % never reads "100 %".
    private var percentText: String {
        let fraction = alert.limit > 0 ? alert.spent / alert.limit : 0
        let floored = Int((Double(truncating: (fraction * 100) as NSDecimalNumber)).rounded(.down))
        return (Double(floored) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    private var message: LocalizedStringResource {
        if alert.state == .over {
            let spent = alert.spent.budgetCurrency(in: locale)
            let limit = alert.limit.budgetCurrency(in: locale)
            return LocalizedStringResource("budgets.alert.over \(categoryName) \(spent) \(limit)", table: "Budgets")
        }
        return LocalizedStringResource("budgets.alert.near \(categoryName) \(percentText)", table: "Budgets")
    }

    var body: some View {
        HStack(alignment: .top, spacing: BifazSpacing.s) {
            BifazIconView(alert.state.budgetIcon, size: 20, relativeTo: .body)
                .foregroundStyle(alert.state.budgetColor)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(message)
                .font(.bifazSubheadline.monospacedDigit())
                .foregroundStyle(Color.bifazInk)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                BifazIconView(.close, size: 16, relativeTo: .body)
                    .foregroundStyle(Color.bifazInk)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, BifazSpacing.m)
        .padding(.vertical, BifazSpacing.xxs)
        .background(tint, in: RoundedRectangle(cornerRadius: BifazRadius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(message))
        .accessibilityAction(named: Text("budgets.alert.dismiss", tableName: "Budgets"), onDismiss)
        .accessibilityIdentifier("ui.budgetAlert")
    }
}

// MARK: - Previews

private struct BannerSamples: View {
    var body: some View {
        let samples = BudgetPreviewData.samples
        VStack(spacing: BifazSpacing.m) {
            ForEach(Array(samples.current.enumerated()), id: \.offset) { _, status in
                if let alert = BudgetService.alert(before: nil, after: status) {
                    BudgetAlertBanner(
                        alert: alert,
                        categoryName: samples.categories[status.categoryID]?.displayName ?? "",
                        onDismiss: {}
                    )
                }
            }
        }
        .padding(.horizontal, BifazSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}

#Preview("Light") { BannerSamples() }

#Preview("Dark") { BannerSamples().preferredColorScheme(.dark) }

#Preview("Large text") { BannerSamples().dynamicTypeSize(.accessibility3) }
