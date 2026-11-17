import SwiftUI
import BifazModels

/// A row in the expense list: category icon tinted with the space colour,
/// merchant, category and date, the amount, and small indicators for the space
/// and a pending receipt. VoiceOver reads it as one element. At accessibility
/// text sizes the amount and indicators move below the merchant.
public struct ExpenseRow: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var tileSide: CGFloat = 40

    private let merchant: String
    private let categoryName: String?
    private let categorySymbol: String?
    private let date: Date
    private let amount: Decimal
    private let currencyCode: String
    private let space: Space
    private let receiptState: ReceiptThumbnail.State

    public init(
        merchant: String,
        categoryName: String?,
        categorySymbol: String?,
        date: Date,
        amount: Decimal,
        currencyCode: String = "EUR",
        space: Space,
        receiptState: ReceiptThumbnail.State
    ) {
        self.merchant = merchant
        self.categoryName = categoryName
        self.categorySymbol = categorySymbol
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.space = space
        self.receiptState = receiptState
    }

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BifazSpacing.xs) {
                    HStack(alignment: .top, spacing: BifazSpacing.s) {
                        iconTile
                        details
                    }
                    HStack(spacing: BifazSpacing.s) {
                        AmountView(amount, currencyCode: currencyCode, style: .row)
                        indicators
                    }
                }
            } else {
                HStack(spacing: BifazSpacing.s) {
                    iconTile
                    details
                    Spacer(minLength: BifazSpacing.xs)
                    VStack(alignment: .trailing, spacing: BifazSpacing.xxs) {
                        AmountView(amount, currencyCode: currencyCode, style: .row)
                        indicators
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var iconTile: some View {
        Image(systemName: categorySymbol ?? "tag.fill")
            .font(.bifazBody)
            .foregroundStyle(space.color)
            .frame(width: tileSide, height: tileSide)
            .background(
                space.color.opacity(0.14),
                in: RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            Text(verbatim: merchant)
                .font(.bifazHeadline)
                .foregroundStyle(Color.bifazInk)
            Text(verbatim: metadata)
                .font(.bifazCaption)
                .foregroundStyle(Color.bifazInkSecondary)
        }
    }

    private var indicators: some View {
        HStack(spacing: BifazSpacing.xxs) {
            if receiptState == .pending {
                Image(systemName: "doc.badge.clock")
                    .foregroundStyle(Color.bifazWarning)
            }
            Image(systemName: space.symbolName)
                .foregroundStyle(space.color)
        }
        .font(.bifazLabel)
        .accessibilityHidden(true)
    }

    private var category: String {
        if let categoryName, !categoryName.isEmpty { return categoryName }
        return LocalizedStringResource("expenseRow.uncategorised", bundle: .module).resolved(in: locale)
    }

    private var metadata: String {
        "\(category) · \(date.formatted(.dateTime.day().month(.abbreviated).locale(locale)))"
    }

    private var accessibilityText: String {
        let dateText = date.formatted(.dateTime.day().month(.wide).locale(locale))
        let amountText = amount.formatted(.currency(code: currencyCode).locale(locale))
        var parts = [
            LocalizedStringResource(
                "expenseRow.accessibility \(merchant) \(category) \(dateText) \(amountText)",
                bundle: .module
            ).resolved(in: locale),
            space.title.resolved(in: locale),
        ]
        if receiptState == .pending {
            parts.append(LocalizedStringResource("receipt.pending", bundle: .module).resolved(in: locale))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Light") {
    ExpenseRowSamples()
}

#Preview("Dark") {
    ExpenseRowSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    ExpenseRowSamples().dynamicTypeSize(.accessibility3)
}

private struct ExpenseRowSamples: View {
    var body: some View {
        VStack(spacing: BifazSpacing.l) {
            ExpenseRow(
                merchant: "Monoprix", categoryName: "Courses", categorySymbol: "cart.fill",
                date: .now, amount: 42.80, space: .personal, receiptState: .none
            )
            ExpenseRow(
                merchant: "SNCF", categoryName: "Transport", categorySymbol: "tram.fill",
                date: .now, amount: 1234.50, space: .pro, receiptState: .pending
            )
            ExpenseRow(
                merchant: "Boulangerie Paul", categoryName: nil, categorySymbol: nil,
                date: .now, amount: 4.30, space: .personal, receiptState: .attached
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
