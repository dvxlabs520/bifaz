import SwiftUI
import Charts
import BifazModels
import BifazDesign

/// The last six months as bars. With "All" Pro and Personal are stacked; with one
/// space, a single bar in that space's colour. The selected month is highlighted.
struct EvolutionChart: View {
    let bars: [MonthBar]
    let space: SpaceFilter
    let selectedMonth: Date
    let onSelect: (Date) -> Void

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 160
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    init(bars: [MonthBar], space: SpaceFilter, selectedMonth: Date, onSelect: @escaping (Date) -> Void) {
        self.bars = bars
        self.space = space
        self.selectedMonth = selectedMonth
        self.onSelect = onSelect
    }

    private struct Segment: Identifiable {
        var month: Date
        var space: Space
        var value: Double
        var id: String { "\(month.timeIntervalSince1970)-\(space.rawValue)" }
    }

    private var segments: [Segment] {
        bars.flatMap { bar -> [Segment] in
            switch space {
            case .all:
                [Segment(month: bar.month, space: .pro, value: bar.pro.doubleValue),
                 Segment(month: bar.month, space: .personal, value: bar.personal.doubleValue)]
            case .pro: [Segment(month: bar.month, space: .pro, value: bar.pro.doubleValue)]
            case .personal: [Segment(month: bar.month, space: .personal, value: bar.personal.doubleValue)]
            }
        }
    }

    private func isSelected(_ month: Date) -> Bool {
        calendar.isDate(month, equalTo: selectedMonth, toGranularity: .month)
    }

    private func spaceName(_ space: Space) -> String {
        String(localized: space.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            chart
            if space == .all { legend }
        }
        .accessibilityRepresentation {
            VStack {
                ForEach(bars) { bar in
                    Button { onSelect(bar.month) } label: { Text(verbatim: monthLabel(bar.month)) }
                        .accessibilityLabel(Text(verbatim: monthLabel(bar.month)))
                        .accessibilityValue(Text(verbatim: value(for: bar)))
                        .accessibilityAddTraits(isSelected(bar.month) ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .accessibilityIdentifier("ui.evolutionChart")
    }

    private var chart: some View {
        Chart(segments) { segment in
            BarMark(
                x: .value("Month", segment.month, unit: .month),
                y: .value("Amount", segment.value),
                width: .ratio(0.6)
            )
            .foregroundStyle(segment.space.color)
            .opacity(isSelected(segment.month) ? 1 : 0.35)
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: bars.map(\.month)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    .font(.bifazLabel)
                    .foregroundStyle(Color.bifazInkSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.bifazHairline)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(verbatim: amount.formatted(.currency(code: "EUR").notation(.compactName).precision(.fractionLength(0)).locale(locale)))
                            .font(.bifazLabel.monospacedDigit())
                            .foregroundStyle(Color.bifazInkSecondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { tap in
                            guard let plot = proxy.plotFrame else { return }
                            let x = tap.location.x - geometry[plot].origin.x
                            guard let date: Date = proxy.value(atX: x) else { return }
                            // The bar whose month holds the tapped date (bars span a whole
                            // month), else the one whose middle is closest.
                            let middle = { (bar: MonthBar) in bar.month.addingTimeInterval(15 * 86_400) }
                            let hit = bars.first { calendar.isDate($0.month, equalTo: date, toGranularity: .month) }
                                ?? bars.min { abs(middle($0).timeIntervalSince(date)) < abs(middle($1).timeIntervalSince(date)) }
                            if let hit { onSelect(hit.month) }
                        }
                    )
            }
        }
        .frame(height: height)
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BifazSpacing.m) { legendItems }
            VStack(alignment: .leading, spacing: BifazSpacing.xxs) { legendItems }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var legendItems: some View {
        ForEach([Space.pro, Space.personal], id: \.self) { item in
            HStack(spacing: BifazSpacing.xxs) {
                RoundedRectangle(cornerRadius: 2).fill(item.color).frame(width: 10, height: 10)
                Text(item.title).font(.bifazCaption).foregroundStyle(Color.bifazInkSecondary)
            }
        }
    }

    // MARK: Accessibility text

    private func monthLabel(_ month: Date) -> String {
        month.formatted(.dateTime.month(.wide).year().locale(locale))
    }

    private func currency(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "EUR").locale(locale))
    }

    private func value(for bar: MonthBar) -> String {
        switch space {
        case .all:
            "\(currency(bar.total)), \(spaceName(.pro)) \(currency(bar.pro)), \(spaceName(.personal)) \(currency(bar.personal))"
        case .pro: currency(bar.pro)
        case .personal: currency(bar.personal)
        }
    }
}

private extension Decimal {
    var doubleValue: Double { (self as NSDecimalNumber).doubleValue }
}

// MARK: - Previews

private struct EvolutionChartSamples: View {
    var space: SpaceFilter = .all
    var body: some View {
        let summary = SummaryPreviewData.summary(.all)
        EvolutionChart(bars: summary.evolution, space: space, selectedMonth: summary.month.start) { _ in }
            .padding(BifazSpacing.screen)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.bifazPaper)
    }
}

#Preview("Light") { EvolutionChartSamples() }
#Preview("Dark") { EvolutionChartSamples().preferredColorScheme(.dark) }
#Preview("Large text") { EvolutionChartSamples().dynamicTypeSize(.accessibility3) }
#Preview("Pro only") { EvolutionChartSamples(space: .pro) }
