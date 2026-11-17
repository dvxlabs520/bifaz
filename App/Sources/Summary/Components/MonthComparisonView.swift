import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// One line under the month total: how this month compares with the previous one.
/// Neutral tones: spending going up is not an error. Icon and text, never colour alone.
struct MonthComparisonView: View {
    let comparison: MonthComparison
    let previousMonth: Date

    @Environment(\.locale) private var locale

    private enum Trend { case up, down, flat }

    private var trend: Trend {
        if comparison.difference > 0 { .up }
        else if comparison.difference < 0 { .down }
        else { .flat }
    }

    init(comparison: MonthComparison, previousMonth: Date) {
        self.comparison = comparison
        self.previousMonth = previousMonth
    }

    private var text: String {
        let month = previousMonth.formatted(.dateTime.month(.wide).locale(locale))
        let amount = (comparison.difference.magnitude as Decimal)
            .formatted(.currency(code: "EUR").locale(locale))
        let percent = (comparison.fraction as NSDecimalNumber).doubleValue
            .formatted(.percent.precision(.fractionLength(0...1)).sign(strategy: .always()).locale(locale))
        switch (trend, comparison.isMonthInProgress) {
        case (.up, false): return String(localized: "summary.change.up \(amount) \(month) \(percent)", table: "Summary")
        case (.down, false): return String(localized: "summary.change.down \(amount) \(month) \(percent)", table: "Summary")
        case (.flat, false): return String(localized: "summary.change.flat \(month)", table: "Summary")
        case (.up, true): return String(localized: "summary.change.up.partial \(amount) \(month) \(percent)", table: "Summary")
        case (.down, true): return String(localized: "summary.change.down.partial \(amount) \(month) \(percent)", table: "Summary")
        case (.flat, true): return String(localized: "summary.change.flat.partial \(month)", table: "Summary")
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
            icon
            Text(verbatim: text)
                .font(.bifazSubheadline)
                .foregroundStyle(Color.bifazInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier("ui.monthComparison")
    }

    @ViewBuilder private var icon: some View {
        switch trend {
        case .up: BifazIconView(.chevronDown, size: 14, relativeTo: .subheadline).rotationEffect(.degrees(180)).foregroundStyle(Color.bifazInkSecondary)
        case .down: BifazIconView(.chevronDown, size: 14, relativeTo: .subheadline).foregroundStyle(Color.bifazInkSecondary)
        case .flat: BifazIconView(.check, size: 14, relativeTo: .subheadline).foregroundStyle(Color.bifazInkSecondary)
        }
    }
}

private struct MonthComparisonSamples: View {
    var body: some View {
        let october = SummaryPreviewData.october
        VStack(alignment: .leading, spacing: BifazSpacing.m) {
            ForEach(Array(SummaryPreviewData.comparisons.enumerated()), id: \.offset) { _, comparison in
                MonthComparisonView(comparison: comparison, previousMonth: october)
            }
        }
        .padding(BifazSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}

#Preview("Light") { MonthComparisonSamples() }
#Preview("Dark") { MonthComparisonSamples().preferredColorScheme(.dark) }
#Preview("Large text") { MonthComparisonSamples().dynamicTypeSize(.accessibility3) }

/// Sample figures for the Summary component previews. The summary value types have
/// no public initialisers, so they are produced by `SummaryCalculator` itself.
enum SummaryPreviewData {
    static let calendar = Calendar.current
    static func date(_ month: Int, _ day: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? .now
    }
    static var october: Date { date(10, 1) }
    static var november: Date { date(11, 1) }

    static let categories: [ExpenseCategory] = [
        ExpenseCategory(name: "Transport", iconName: BifazIcon.transport.rawValue, space: .pro),
        ExpenseCategory(name: "Restaurants", iconName: BifazIcon.meal.rawValue, space: .pro),
        ExpenseCategory(name: "Logiciels", iconName: BifazIcon.software.rawValue, space: .pro),
        ExpenseCategory(name: "Courses", iconName: BifazIcon.groceries.rawValue, space: .personal),
        ExpenseCategory(name: "Téléphone", iconName: BifazIcon.phone.rawValue, space: .pro),
        ExpenseCategory(name: "Santé", iconName: BifazIcon.health.rawValue, space: .personal),
        ExpenseCategory(name: "Loisirs", iconName: BifazIcon.leisure.rawValue, space: .personal),
        ExpenseCategory(name: "Animaux", iconName: BifazIcon.pets.rawValue, space: .personal),
    ]
    static var categoriesByID: [UUID: ExpenseCategory] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    static func vat(_ rate: Decimal, _ total: Decimal) -> [VATPart] { [VATPart.computed(total: total, rate: rate)] }

    static var figures: [ExpenseFigure] {
        var list: [ExpenseFigure] = []
        let perMonth: [(Int, Decimal, Decimal)] = [(6, 420, 310), (7, 380, 290), (8, 610, 240), (9, 150, 410), (10, 520, 380), (11, 610, 205)]
        for (month, pro, personal) in perMonth {
            list.append(ExpenseFigure(date: date(month), space: .pro, amount: pro, categoryID: categories[0].id, vatLines: vat(0.2, pro)))
            list.append(ExpenseFigure(date: date(month, 12), space: .personal, amount: personal, categoryID: categories[3].id))
        }
        let extra: [(Int, Decimal, Space, Decimal?)] = [
            (11, 180, .pro, 0.2), (11, 96, .pro, 0.1), (11, 55.5, .pro, 0.055), (11, 120, .pro, 0.2), (11, 60, .personal, nil),
            (11, 30, .personal, nil), (11, 12, .personal, nil), (11, 8, .personal, nil), (10, 90, .pro, 0.2), (9, 70, .pro, 0.1),
        ]
        for (index, item) in extra.enumerated() {
            let id = index == 7 ? nil : categories[(index % 7) + 1].id
            list.append(ExpenseFigure(
                date: date(item.0, 14 + index), space: item.2, amount: item.1, categoryID: id,
                vatLines: item.3.map { vat($0, item.1) } ?? []
            ))
        }
        return list
    }

    static func summary(_ space: SpaceFilter = .all) -> MonthSummary {
        SummaryCalculator.summary(
            of: figures, month: ExpenseGrouping.monthInterval(containing: date(11, 1)),
            space: space, now: date(11, 17), calendar: calendar
        )
    }

    static var comparisons: [MonthComparison] {
        let finished = SummaryCalculator.summary(
            of: figures, month: ExpenseGrouping.monthInterval(containing: date(11, 1)), space: .all, now: date(12, 20), calendar: calendar
        ).comparison
        let running = summary().comparison
        return [finished, running].compactMap { $0 }
    }
}
