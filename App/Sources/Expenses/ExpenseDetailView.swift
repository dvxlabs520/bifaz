import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// One expense in full: header with icon, merchant, amount and date, then
/// label/value rows separated by hairlines.
struct ExpenseDetailView: View {
    let expense: Expense

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @State private var isEditing = false

    private static let longDate = Date.FormatStyle.dateTime.day().month(.wide).year()
    private static let timestamp = Date.FormatStyle.dateTime.day().month(.abbreviated).year().hour().minute()

    var body: some View {
        if expense.isDeleted || expense.modelContext == nil {
            // The expense disappeared while shown: go back.
            Color.bifazPaper
                .onAppear { dismiss() }
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, BifazSpacing.xl)
                rows
                timestamps
                    .padding(.top, BifazSpacing.l)
            }
            .padding(.horizontal, BifazSpacing.screen)
            .padding(.top, BifazSpacing.m)
            .padding(.bottom, BifazSpacing.xxl)
        }
        .background(Color.bifazPaper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Text("detail.edit", tableName: "History")
                }
                .accessibilityIdentifier("ui.detailEdit")
            }
        }
        .sheet(isPresented: $isEditing) {
            ExpenseFormView(editing: expense, onDeleted: { dismiss() })
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            CategoryIcon(
                icon: expense.category?.icon ?? .other,
                tint: expense.space.color,
                background: expense.space.tint,
                badge: expense.space,
                side: 56
            )
            .padding(.bottom, BifazSpacing.xxs)
            Group {
                if expense.merchant.isEmpty {
                    Text("detail.merchant.empty", tableName: "History")
                } else {
                    Text(verbatim: expense.merchant)
                }
            }
            .font(.bifazTitle)
            .foregroundStyle(Color.bifazInk)
            .accessibilityAddTraits(.isHeader)
            AmountView(expense.amountInEUR, style: .hero)
            Text(verbatim: expense.date.formatted(Self.longDate.locale(locale)))
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rows

    private var showsVAT: Bool { isVATRegistered && expense.vatRate != nil }

    private var rows: some View {
        VStack(spacing: 0) {
            HairlineDivider()
            DetailRow("detail.space") {
                HStack(spacing: BifazSpacing.xs) {
                    BifazIconView(expense.space.icon, size: 18)
                        .foregroundStyle(expense.space.color)
                    Text(expense.space.title)
                }
            }
            HairlineDivider()
            DetailRow("detail.category") {
                if let category = expense.category {
                    HStack(spacing: BifazSpacing.xs) {
                        BifazIconView(category.icon, size: 18)
                            .foregroundStyle(expense.space.color)
                        Text(verbatim: category.displayName)
                    }
                } else {
                    Text("detail.category.none", tableName: "History")
                        .foregroundStyle(Color.bifazInkSecondary)
                }
            }
            if showsVAT, let rate = expense.vatRate {
                HairlineDivider()
                DetailRow("detail.vat") {
                    Text(verbatim: VATRate(fraction: rate)?.percentText
                        ?? (rate as NSDecimalNumber).doubleValue.formatted(.percent.precision(.fractionLength(0...1))))
                }
                HairlineDivider()
                DetailRow("detail.vatAmount") {
                    AmountView(
                        expense.vatAmount ?? VATCalculator.vatAmount(includedIn: expense.amount, rate: rate),
                        currencyCode: expense.currencyCode,
                        style: .row
                    )
                }
                HairlineDivider()
                DetailRow("detail.amountExclVAT") {
                    AmountView(
                        VATCalculator.amountExcludingVAT(expense.amount, rate: rate),
                        currencyCode: expense.currencyCode,
                        style: .row
                    )
                }
            }
            if !expense.note.isEmpty {
                HairlineDivider()
                DetailRow("detail.note") {
                    Text(verbatim: expense.note)
                }
            }
            HairlineDivider()
            DetailRow("detail.origin") {
                Text(expense.source.title)
            }
            HairlineDivider()
            DetailRow("detail.status") {
                Text(expense.status.title)
                    .foregroundStyle(expense.status == .receiptPending ? Color.bifazWarning : Color.bifazInk)
            }
            HairlineDivider()
        }
    }

    private var timestamps: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            Text("detail.created \(expense.createdAt.formatted(Self.timestamp.locale(locale)))", tableName: "History")
            Text("detail.updated \(expense.updatedAt.formatted(Self.timestamp.locale(locale)))", tableName: "History")
        }
        .font(.bifazCaption)
        .foregroundStyle(Color.bifazInkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A label on the left, a value on the right; stacked at accessibility sizes.
private struct DetailRow<Value: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let label: LocalizedStringResource
    private let value: Value

    init(_ key: String.LocalizationValue, @ViewBuilder value: () -> Value) {
        label = LocalizedStringResource(key, table: "History")
        self.value = value()
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: BifazSpacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: BifazSpacing.m))
        layout {
            Text(label)
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInkSecondary)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: BifazSpacing.xs) }
            value
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInk)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .padding(.vertical, BifazSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
private struct DetailPreview: View {
    let container = HistoryPreviewData.container()

    var body: some View {
        DetailHost()
            .modelContainer(container)
    }
}

private struct DetailHost: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    var body: some View {
        NavigationStack {
            if let expense = expenses.first(where: { $0.merchant == "SNCF" }) {
                ExpenseDetailView(expense: expense)
            }
        }
    }
}

#Preview("Light") {
    DetailPreview()
}

#Preview("Dark") {
    DetailPreview().preferredColorScheme(.dark)
}

#Preview("Large text") {
    DetailPreview().dynamicTypeSize(.accessibility3)
}
#endif
