import Foundation
import CoreGraphics
import Testing
@testable import BifazDesign

@Suite("v2 components")
struct V2ComponentsTests {
    // MARK: TrendLine

    @Test("Empty and single point")
    func trendEmptyAndSingle() {
        #expect(TrendLine.normalized([]).isEmpty)
        #expect(TrendLine.normalized([42]) == [1])
        #expect(TrendLine.normalized([0]) == [0])
    }

    @Test("All values equal sit at the top; all zero at the bottom")
    func trendEqual() {
        #expect(TrendLine.normalized([5, 5, 5]) == [1, 1, 1])
        #expect(TrendLine.normalized([0, 0]) == [0, 0])
    }

    @Test("Increasing values scale against a baseline of 0")
    func trendIncreasing() {
        #expect(TrendLine.normalized([0, 50, 100]) == [0, 0.5, 1])
        #expect(TrendLine.normalized([25, 50, 100]) == [0.25, 0.5, 1])
    }

    @Test("Decimals and negatives")
    func trendDecimals() {
        let values = TrendLine.normalized([Decimal(string: "1.25")!, Decimal(string: "2.5")!, Decimal(string: "10")!])
        #expect(values.count == 3)
        #expect(abs(values[0] - 0.125) < 0.0001)
        #expect(abs(values[1] - 0.25) < 0.0001)
        #expect(values[2] == 1)
        #expect(TrendLine.normalized([-5, 10]) == [0, 1])
    }

    // MARK: DayHeader

    static let paris: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()
    static func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        paris.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    static let now = date(11, 19)

    static func title(_ day: Date, _ identifier: String) -> String {
        DayHeader.title(for: day, now: now, calendar: paris, locale: Locale(identifier: identifier))
            .replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    @Test("Today and yesterday are words", arguments: [
        ("en", "Today", "Yesterday"),
        ("es", "Hoy", "Ayer"),
        ("fr", "Aujourd’hui", "Hier"),
    ])
    func todayYesterday(language: String, today: String, yesterday: String) {
        #expect(Self.title(Self.now, language) == today)
        #expect(Self.title(Self.date(11, 18), language) == yesterday)
    }

    @Test("Older days: weekday, day and abbreviated month", arguments: [
        ("fr_FR", "lundi 16 nov."),
        ("es_ES", "lunes, 16 nov"),
        ("en_GB", "Monday 16 Nov"),
    ])
    func older(locale: String, expected: String) {
        #expect(Self.title(Self.date(11, 16), locale) == expected)
    }

    @Test("A day in another year includes the year")
    func otherYear() {
        #expect(Self.title(Self.date(12, 24, year: 2025), "fr_FR").contains("2025"))
        #expect(!Self.title(Self.date(11, 16), "fr_FR").contains("2026"))
    }

    @Test("Yesterday across midnight uses the calendar's day")
    func lateEvening() {
        let lateNow = Self.paris.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 0, minute: 30))!
        let evening = Self.paris.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 23, minute: 50))!
        #expect(DayHeader.title(for: evening, now: lateNow, calendar: Self.paris, locale: Locale(identifier: "en")) == "Yesterday")
    }
}
