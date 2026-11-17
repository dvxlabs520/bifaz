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
    @State private var isRepeating = false

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
                ReceiptSection(expense: expense)
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
            if !expense.isForeignCurrency, expense.recurringRule == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isRepeating = true
                    } label: {
                        Text("detail.repeat", tableName: "History")
                    }
                    .accessibilityIdentifier("ui.detailRepeat")
                }
            }
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
        .sheet(isPresented: $isRepeating) {
            RecurringRuleEditorView(template: RecurringRuleEditorView.template(repeating: ExpenseDraft(expense: expense)))
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
            if expense.isForeignCurrency {
                Text(verbatim: expense.amount.formatted(.currency(code: expense.currencyCode).locale(locale)))
                    .font(.bifazBody)
                    .monospacedDigit()
                    .foregroundStyle(Color.bifazInkSecondary)
            }
            Text(verbatim: expense.date.formatted(Self.longDate.locale(locale)))
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rows

    private var showsVAT: Bool { isVATRegistered && !vatLines.isEmpty }

    /// The stored lines (schema v2).
    private var vatLines: [VATPart] { expense.sortedVATLines.map(VATPart.init) }

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
            if expense.space == .pro, let client = expense.client {
                HairlineDivider()
                DetailRow("detail.client") { Text(verbatim: client.name) }
            }
            if expense.space == .pro, let project = expense.project {
                HairlineDivider()
                DetailRow("detail.project") { Text(verbatim: project.name) }
            }
            if expense.isForeignCurrency, let rate = expense.exchangeRate {
                HairlineDivider()
                DetailRow("detail.rate") {
                    Text(verbatim: "1 € = \(rate.formatted(.number.precision(.fractionLength(0...6)))) \(expense.currencyCode)")
                }
                HairlineDivider()
                DetailRow("detail.rateSource") {
                    rateSource
                }
            }
            if let rule = expense.recurringRule {
                HairlineDivider()
                DetailRow("detail.recurring") {
                    Text(verbatim: rule.merchant.isEmpty ? String(localized: rule.frequency.title) : "\(rule.merchant) · \(String(localized: rule.frequency.title))")
                }
            }
            if showsVAT {
                let lines = vatLines
                if lines.count == 1, let line = lines.first {
                    HairlineDivider()
                    DetailRow("detail.vat") { Text(verbatim: line.rateText) }
                } else {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HairlineDivider()
                        DetailRow("detail.vatLine \(line.rateText)") {
                            AmountView(line.vat, currencyCode: expense.currencyCode, style: .row)
                        }
                    }
                }
                HairlineDivider()
                DetailRow("detail.vatAmount") {
                    AmountView(lines.reduce(0) { $0 + $1.vat }, currencyCode: expense.currencyCode, style: .row)
                }
                HairlineDivider()
                DetailRow("detail.amountExclVAT") {
                    AmountView(lines.reduce(0) { $0 + $1.base }, currencyCode: expense.currencyCode, style: .row)
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

    @ViewBuilder
    private var rateSource: some View {
        let day = expense.exchangeRateDate.map { $0.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)) } ?? ""
        switch expense.exchangeRateSource {
        case .ecb: Text("detail.rateSource.ecb \(day)", tableName: "History")
        case .ecbApproximate: Text("detail.rateSource.approximate \(day)", tableName: "History").foregroundStyle(Color.bifazWarning)
        case .manual, nil: Text("detail.rateSource.manual", tableName: "History")
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
