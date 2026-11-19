import SwiftUI
import BifazModels

/// A row in the expense list. It sits directly on the screen background: a
/// merchant monogram with the space badge, merchant and category (or a
/// "Receipt missing" warning), and the amount with the date (or the time, in a
/// list grouped by day) below it on the right. VoiceOver reads it as one element.
/// At accessibility text sizes the
/// amount and date move under the text.
public struct ExpenseRow: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let merchant: String
    private let categoryName: String?
    private let categoryIcon: BifazIcon?
    private let date: Date
    private let amount: Decimal
    private let currencyCode: String
    private let space: Space
    private let receiptState: ReceiptThumbnail.State
    /// For a foreign-currency expense: the original amount ("48,00 $US"), shown
    /// under the euro amount instead of the date.
    private let originalAmount: (amount: Decimal, currencyCode: String)?
    /// Show the time ("14:32") instead of the date: the day header already says the day.
    private let timeOnly: Bool

    public init(
        merchant: String,
        categoryName: String?,
        categoryIcon: BifazIcon?,
        date: Date,
        amount: Decimal,
        currencyCode: String = "EUR",
        space: Space,
        receiptState: ReceiptThumbnail.State,
        originalAmount: (amount: Decimal, currencyCode: String)? = nil,
        timeOnly: Bool = false
    ) {
        self.timeOnly = timeOnly
        self.originalAmount = originalAmount
        self.merchant = merchant
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.space = space
        self.receiptState = receiptState
    }

    public var body: some View {
        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: BifazSpacing.s) {
            MonogramAvatar(name: merchant, space: space)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BifazSpacing.xs) {
                    details
                    trailing(alignment: .leading)
                }
            } else {
                details
                Spacer(minLength: BifazSpacing.xs)
                trailing(alignment: .trailing)
            }
        }
        .padding(.vertical, BifazSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: merchant)
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInk)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            subtitle
                .font(.bifazCaption)
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if receiptState == .pending {
            // An HStack rather than a Label: inside a List, Label gets an icon
            // column that pushes the text away and moves the row separator.
            HStack(spacing: BifazSpacing.xxs) {
                BifazIconView(.receiptPending, size: 14, relativeTo: .caption)
                Text("expenseRow.receiptMissing", bundle: .module)
            }
            .foregroundStyle(Color.bifazWarning)
        } else if let categoryName, !categoryName.isEmpty {
            Text(verbatim: categoryName)
                .foregroundStyle(Color.bifazInkSecondary)
        } else {
            Text("expenseRow.uncategorised", bundle: .module)
                .foregroundStyle(Color.bifazInkSecondary)
        }
    }

    private func trailing(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            AmountView(amount, currencyCode: currencyCode, style: .row)
            Group {
                if let originalAmount {
                    Text(verbatim: originalAmount.amount.formatted(.currency(code: originalAmount.currencyCode).locale(locale))
                         + " · " + captionDate)
                } else {
                    Text(verbatim: captionDate)
                }
            }
            .font(.bifazCaption)
            .monospacedDigit()
            .foregroundStyle(Color.bifazInkSecondary)
        }
    }

    private var captionDate: String {
        timeOnly
            ? date.formatted(.dateTime.hour().minute().locale(locale))
            : date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    private var accessibilityText: String {
        let category = categoryName.flatMap { $0.isEmpty ? nil : $0 }
            ?? LocalizedStringResource("expenseRow.uncategorised", bundle: .module).resolved(in: locale)
        let dateText = timeOnly
            ? date.formatted(.dateTime.hour().minute().locale(locale))
            : date.formatted(.dateTime.day().month(.wide).locale(locale))
        var amountText = amount.formatted(.currency(code: currencyCode).locale(locale))
        if let originalAmount {
            amountText += ", " + originalAmount.amount.formatted(.currency(code: originalAmount.currencyCode).locale(locale))
        }
        var parts = [
            LocalizedStringResource(
                "expenseRow.accessibility \(merchant) \(category) \(dateText) \(amountText)",
                bundle: .module
            ).resolved(in: locale),
            space.title.resolved(in: locale),
        ]
        if receiptState == .pending {
            // The same words as on screen ("Receipt missing"): the audit flags a row whose
            // label does not say what it shows, and VoiceOver should read what is drawn.
            parts.append(LocalizedStringResource("expenseRow.receiptMissing", bundle: .module).resolved(in: locale))
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
        VStack(spacing: 0) {
            ExpenseRow(
                merchant: "Monoprix", categoryName: "Courses", categoryIcon: .groceries,
                date: .now, amount: 42.80, space: .personal, receiptState: .none
            )
            HairlineDivider(leadingInset: 48)
            ExpenseRow(
                merchant: "SNCF", categoryName: "Transport", categoryIcon: .transport,
                date: .now, amount: 1284.50, space: .pro, receiptState: .pending
            )
            HairlineDivider(leadingInset: 48)
            ExpenseRow(
                merchant: "Adobe", categoryName: "Logiciels", categoryIcon: .software,
                date: .now, amount: 65.99, space: .pro, receiptState: .attached
            )
            HairlineDivider(leadingInset: 48)
            ExpenseRow(
                merchant: "Boulangerie Paul", categoryName: nil, categoryIcon: nil,
                date: .now, amount: 4.30, space: .personal, receiptState: .attached, timeOnly: true
            )
            HairlineDivider(leadingInset: 48)
            ExpenseRow(
                merchant: "Mercadona", categoryName: "Compras", categoryIcon: .groceries,
                date: .now, amount: 48.00, space: .personal, receiptState: .none,
                originalAmount: (48, "USD"), timeOnly: true
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
