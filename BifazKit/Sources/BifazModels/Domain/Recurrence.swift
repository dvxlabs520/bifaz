import Foundation

/// Dates of a recurring rule. Every occurrence is computed from the start date
/// (the anchor), never from the previous one, so a rule started on the 31st
/// falls on the 30th in April and back on the 31st in May, and one started on
/// 29 February falls on the 28th in other years and on the 29th in leap years.
public enum RecurrenceCalendar {
    /// The `index`-th occurrence (0 = the start), at the start of its day.
    public static func occurrence(_ index: Int, start: Date, frequency: RecurrenceFrequency, calendar: Calendar) -> Date? {
        let anchor = calendar.startOfDay(for: start)
        let date: Date? = switch frequency {
        case .weekly: calendar.date(byAdding: .day, value: 7 * index, to: anchor)
        case .monthly: calendar.date(byAdding: .month, value: index, to: anchor)
        case .quarterly: calendar.date(byAdding: .month, value: 3 * index, to: anchor)
        case .yearly: calendar.date(byAdding: .year, value: index, to: anchor)
        }
        return date.map { calendar.startOfDay(for: $0) }
    }

    /// Occurrences in `[from, through]` (both days included), within the rule's
    /// start and optional end. At most `limit` (a safety net for very old rules).
    public static func occurrences(
        start: Date,
        end: Date?,
        frequency: RecurrenceFrequency,
        from: Date,
        through: Date,
        calendar: Calendar,
        limit: Int = 1000
    ) -> [Date] {
        let first = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: min(through, end ?? through))
        guard first <= last else { return [] }
        var dates: [Date] = []
        var index = firstIndex(onOrAfter: first, start: start, frequency: frequency, calendar: calendar)
        while dates.count < limit, let date = occurrence(index, start: start, frequency: frequency, calendar: calendar), date <= last {
            if date >= first { dates.append(date) }
            index += 1
        }
        return dates
    }

    /// The next occurrence on or after `date`, if the rule has not ended.
    public static func next(onOrAfter date: Date, start: Date, end: Date?, frequency: RecurrenceFrequency, calendar: Calendar) -> Date? {
        let index = firstIndex(onOrAfter: calendar.startOfDay(for: date), start: start, frequency: frequency, calendar: calendar)
        guard let next = occurrence(index, start: start, frequency: frequency, calendar: calendar) else { return nil }
        if let end, next > calendar.startOfDay(for: end) { return nil }
        return next
    }

    /// A first guess of the index whose occurrence is on or after `date`, then corrected.
    private static func firstIndex(onOrAfter date: Date, start: Date, frequency: RecurrenceFrequency, calendar: Calendar) -> Int {
        let anchor = calendar.startOfDay(for: start)
        guard date > anchor else { return 0 }
        let estimate: Int = switch frequency {
        case .weekly: (calendar.dateComponents([.day], from: anchor, to: date).day ?? 0) / 7
        case .monthly: calendar.dateComponents([.month], from: anchor, to: date).month ?? 0
        case .quarterly: (calendar.dateComponents([.month], from: anchor, to: date).month ?? 0) / 3
        case .yearly: calendar.dateComponents([.year], from: anchor, to: date).year ?? 0
        }
        var index = max(0, estimate - 1)
        while let occurrence = occurrence(index, start: start, frequency: frequency, calendar: calendar), occurrence < date {
            index += 1
        }
        return index
    }

    /// What the rule costs per month on average (weekly × 52/12, quarterly / 3, yearly / 12), to the cent.
    public static func monthlyEquivalent(of amount: Decimal, frequency: RecurrenceFrequency) -> Decimal {
        switch frequency {
        case .weekly: (amount * 52 / 12).rounded(scale: 2)
        case .monthly: amount
        case .quarterly: (amount / 3).rounded(scale: 2)
        case .yearly: (amount / 12).rounded(scale: 2)
        }
    }
}
