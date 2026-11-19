import SwiftUI

/// Header of a day group in the history: "Today" / "Yesterday" / "lundi 16 nov."
/// in the data-label voice on the left, the day total on the right, a hairline
/// below. VoiceOver reads "Yesterday, 93,00 €" as one element.
public struct DayHeader: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let day: Date
    private let total: Decimal
    private let now: Date
    private let calendar: Calendar

    public init(day: Date, total: Decimal, now: Date = .now, calendar: Calendar = .current) {
        self.day = day
        self.total = total
        self.now = now
        self.calendar = calendar
    }

    /// "Today", "Yesterday", otherwise the weekday, day and abbreviated month
    /// ("lundi 16 nov."), with the year when it is not the current one.
    public nonisolated static func title(for day: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return LocalizedStringResource("dayHeader.today", bundle: .module).resolved(in: locale)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return LocalizedStringResource("dayHeader.yesterday", bundle: .module).resolved(in: locale)
        }
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).day().month(.abbreviated)
        if calendar.component(.year, from: day) != calendar.component(.year, from: now) { style = style.year() }
        return day.formatted(style)
    }

    private var titleText: String {
        Self.title(for: day, now: now, calendar: calendar, locale: locale)
    }

    private var totalText: String {
        total.formatted(.currency(code: "EUR").locale(locale))
    }

    public var body: some View {
        VStack(spacing: BifazSpacing.xs) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: BifazSpacing.xxs) { title; totalView }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        title
                        Spacer(minLength: BifazSpacing.xs)
                        totalView
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HairlineDivider()
        }
        .padding(.top, BifazSpacing.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(verbatim: LocalizedStringResource("dayHeader.accessibility \(titleText) \(totalText)", bundle: .module).resolved(in: locale))
        )
        .accessibilityAddTraits(.isHeader)
    }

    private var title: some View {
        Text(verbatim: titleText).bifazDataLabel()
    }

    private var totalView: some View {
        Text(verbatim: totalText)
            .font(.bifazAmount)
            .foregroundStyle(Color.bifazInkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

#Preview("Light") {
    DayHeaderSamples()
}

#Preview("Dark") {
    DayHeaderSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    DayHeaderSamples().dynamicTypeSize(.accessibility3)
}

private struct DayHeaderSamples: View {
    private let now = Date.now
    var body: some View {
        VStack(spacing: BifazSpacing.l) {
            DayHeader(day: now, total: 42.80, now: now)
            DayHeader(day: now.addingTimeInterval(-86_400), total: 93, now: now)
                .environment(\.locale, Locale(identifier: "fr_FR"))
            DayHeader(day: now.addingTimeInterval(-5 * 86_400), total: 1284.50, now: now)
                .environment(\.locale, Locale(identifier: "es_ES"))
            DayHeader(day: now.addingTimeInterval(-5 * 86_400), total: 12.30, now: now)
                .environment(\.locale, Locale(identifier: "fr_FR"))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
