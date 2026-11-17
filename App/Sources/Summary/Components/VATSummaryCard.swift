import SwiftUI
import BifazModels
import BifazDesign

extension VATRateTotal {
    /// "20 %", "8,5 %" for a rate outside the French list, or "Rate not detailed"
    /// for a v1 receipt with several rates. Mirrors `VATPart.rateText`.
    var rateText: String {
        guard let rate else { return String(localized: "vat.rate.unknown") }
        return VATRate(fraction: rate)?.percentText
            ?? (rate as NSDecimalNumber).doubleValue.formatted(.percent.precision(.fractionLength(0...1)))
    }
}

/// VAT paid on Pro expenses (TVA déductible): the month, and the quarter so far.
struct VATSummaryCard: View {
    let vat: VATSummary
    let month: Date

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    init(vat: VATSummary, month: Date) {
        self.vat = vat
        self.month = month
    }

    private var monthName: String {
        month.formatted(.dateTime.month(.wide).locale(locale))
    }

    private var quarterTitle: String {
        let start = vat.quarterInterval.start
        let quarter = ((calendar.component(.month, from: start) - 1) / 3) + 1
        let year = String(calendar.component(.year, from: start))
        let label = switch quarter {
        case 1: String(localized: "summary.vat.quarter.1", table: "Summary")
        case 2: String(localized: "summary.vat.quarter.2", table: "Summary")
        case 3: String(localized: "summary.vat.quarter.3", table: "Summary")
        default: String(localized: "summary.vat.quarter.4", table: "Summary")
        }
        return String(localized: "summary.vat.quarterToDate \(label) \(year) \(monthName)", table: "Summary")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.m) {
            HStack(spacing: BifazSpacing.xs) {
                BifazIconView(.taxes)
                    .foregroundStyle(Color.bifazPro)
                Text("summary.vat.title", tableName: "Summary")
                    .font(.bifazSectionTitle)
                    .foregroundStyle(Color.bifazInk)
                    .accessibilityAddTraits(.isHeader)
            }
            VATBlock(
                title: monthName.localizedCapitalized,
                lines: vat.month,
                total: vat.monthVAT,
                emptyText: String(localized: "summary.vat.none.month", table: "Summary")
            )
            HairlineDivider()
            VATBlock(
                title: quarterTitle,
                lines: vat.quarter,
                total: vat.quarterVAT,
                emptyText: String(localized: "summary.vat.none.quarter", table: "Summary")
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bifazCard()
        .accessibilityIdentifier("ui.vatSummary")
    }
}

private struct VATBlock: View {
    let title: String
    let lines: [VATRateTotal]
    let total: Decimal
    let emptyText: String

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            Text(verbatim: title)
                .font(.bifazSubheadline)
                .foregroundStyle(Color.bifazInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            AmountView(total, style: .medium)
            if lines.isEmpty {
                Text(verbatim: emptyText)
                    .font(.bifazCaption)
                    .foregroundStyle(Color.bifazInkSecondary)
            } else {
                VStack(alignment: .leading, spacing: BifazSpacing.xs) {
                    ForEach(lines) { line in
                        VATLineRow(line: line)
                    }
                }
                .padding(.top, BifazSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VATLineRow: View {
    let line: VATRateTotal

    @Environment(\.locale) private var locale

    private func currency(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "EUR").locale(locale))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: line.rateText)
                    .font(.bifazBody)
                    .foregroundStyle(Color.bifazInk)
                Spacer(minLength: BifazSpacing.xs)
                Text(verbatim: currency(line.vat))
                    .font(.bifazAmount)
                    .foregroundStyle(Color.bifazInk)
            }
            Text("summary.vat.base \(currency(line.base))", tableName: "Summary")
                .font(.bifazCaption.monospacedDigit())
                .foregroundStyle(Color.bifazInkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(line.rateText), \(currency(line.vat)), \(String(localized: "summary.vat.base \(currency(line.base))", table: "Summary"))"))
    }
}

// MARK: - Previews

private struct VATSummaryCardSamples: View {
    var vat: VATSummary

    var body: some View {
        ScrollView {
            VATSummaryCard(vat: vat, month: SummaryPreviewData.november)
                .padding(BifazSpacing.screen)
        }
        .background(Color.bifazPaper)
    }
}

private func sampleVAT() -> VATSummary {
    SummaryPreviewData.summary(.pro).vat!
}

private func emptyMonthVAT() -> VATSummary {
    let summary = SummaryCalculator.summary(
        of: SummaryPreviewData.figures.filter { $0.date < SummaryPreviewData.date(11, 1) },
        month: ExpenseGrouping.monthInterval(containing: SummaryPreviewData.november),
        space: .pro, now: SummaryPreviewData.date(11, 17), calendar: SummaryPreviewData.calendar
    )
    return summary.vat!
}

#Preview("Light") { VATSummaryCardSamples(vat: sampleVAT()) }
#Preview("Dark") { VATSummaryCardSamples(vat: sampleVAT()).preferredColorScheme(.dark) }
#Preview("Large text") { VATSummaryCardSamples(vat: sampleVAT()).dynamicTypeSize(.accessibility3) }
#Preview("No VAT this month") { VATSummaryCardSamples(vat: emptyMonthVAT()) }
