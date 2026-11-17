import Foundation

// Multi-currency (phase 4). The European Central Bank publishes reference rates
// as "1 EUR = x units" on TARGET business days. Bifaz downloads the public daily
// and 90-day tables (no key, no user data in the request), at most once a day and
// only when the user enters a foreign currency, and keeps the last table locally.
// Once an expense is saved its rate is fixed: it is never recalculated.

/// Where the rate of an expense came from.
public enum ExchangeRateSource: String, Codable, Sendable, CaseIterable {
    /// ECB reference rate of the expense's date (or the last business day before it).
    case ecb
    /// ECB rate of another date (expense older than the table, or offline with an old table).
    case ecbApproximate
    /// Typed by the user, or implied by the euro amount the bank charged.
    case manual
}

/// One ECB table: for each date, the rates of each currency (1 EUR = rate units).
public struct ExchangeRateTable: Codable, Sendable, Equatable {
    /// Keyed by the publication day ("yyyy-MM-dd", the ECB's own calendar, CET).
    public var days: [String: [String: Decimal]]
    /// When this copy was downloaded.
    public var downloadedAt: Date

    public init(days: [String: [String: Decimal]], downloadedAt: Date) {
        self.days = days
        self.downloadedAt = downloadedAt
    }

    public var isEmpty: Bool { days.isEmpty }

    /// Currencies with a rate in the latest day.
    public var currencies: [String] {
        guard let latest = days.keys.max(), let rates = days[latest] else { return [] }
        return rates.keys.sorted()
    }

    /// Merges another table (newer values win).
    public func merging(_ other: ExchangeRateTable) -> ExchangeRateTable {
        ExchangeRateTable(days: days.merging(other.days) { _, new in new }, downloadedAt: max(downloadedAt, other.downloadedAt))
    }

    /// Keeps the most recent `count` days (the store does not grow forever).
    public func trimmed(toDays count: Int) -> ExchangeRateTable {
        let keep = Set(days.keys.sorted().suffix(count))
        return ExchangeRateTable(days: days.filter { keep.contains($0.key) }, downloadedAt: downloadedAt)
    }
}

/// A rate chosen for an expense.
public struct ExchangeRateQuote: Sendable, Equatable {
    public var currencyCode: String
    /// 1 EUR = `rate` units of `currencyCode`.
    public var rate: Decimal
    /// The ECB day the rate belongs to (or the day it was typed, for manual rates).
    public var date: Date
    public var source: ExchangeRateSource

    public init(currencyCode: String, rate: Decimal, date: Date, source: ExchangeRateSource) {
        self.currencyCode = currencyCode
        self.rate = rate
        self.date = date
        self.source = source
    }
}

public enum CurrencyConverter {
    /// The ECB's calendar: day keys are Frankfurt dates.
    public static let ecbCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    /// How far from the expense date a rate still counts as that day's
    /// (weekends and bank holidays: the ECB publishes nothing).
    public static let sameDayTolerance = 4

    /// Euros for `amount` units at `rate` (1 EUR = rate units), rounded half up to the cent.
    public static func euros(for amount: Decimal, rate: Decimal) -> Decimal {
        guard rate > 0 else { return 0 }
        return (amount / rate).rounded(scale: 2)
    }

    /// The rate implied by the euro amount the bank charged: amount / euros, kept
    /// to 10 decimals so converting back gives the same euros (the euros are saved
    /// as typed anyway; the rate is for display and reports).
    public static func impliedRate(amount: Decimal, euros: Decimal) -> Decimal? {
        guard amount > 0, euros > 0 else { return nil }
        return (amount / euros).rounded(scale: 10)
    }

    static func dayKey(_ date: Date) -> String {
        let parts = ecbCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return ecbCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// The rate for an expense in `currency` on `date`:
    /// - the ECB day of the expense, or the last business day before it (up to
    ///   `sameDayTolerance` days back): `.ecb`;
    /// - else the closest day in the table, before or after: `.ecbApproximate`;
    /// - nil when the table has no rate for that currency.
    public static func quote(for currency: String, on date: Date, in table: ExchangeRateTable) -> ExchangeRateQuote? {
        let available = table.days.compactMap { key, rates -> (key: String, rate: Decimal)? in
            rates[currency].map { (key, $0) }
        }
        guard !available.isEmpty else { return nil }
        let target = dayKey(date)
        // Same day or the last business day before it.
        if let previous = available.filter({ $0.key <= target }).max(by: { $0.key < $1.key }),
           let day = Self.date(fromKey: previous.key), let targetDay = Self.date(fromKey: target),
           let gap = ecbCalendar.dateComponents([.day], from: day, to: targetDay).day, gap <= sameDayTolerance {
            return ExchangeRateQuote(currencyCode: currency, rate: previous.rate, date: day, source: .ecb)
        }
        // Closest available day otherwise.
        guard let targetDay = Self.date(fromKey: target) else { return nil }
        let closest = available.min { lhs, rhs in
            let l = abs(Self.date(fromKey: lhs.key)?.timeIntervalSince(targetDay) ?? .infinity)
            let r = abs(Self.date(fromKey: rhs.key)?.timeIntervalSince(targetDay) ?? .infinity)
            return l != r ? l < r : lhs.key > rhs.key
        }!
        return ExchangeRateQuote(
            currencyCode: currency, rate: closest.rate,
            date: Self.date(fromKey: closest.key) ?? targetDay, source: .ecbApproximate
        )
    }
}

// MARK: - ECB XML

/// Parses the ECB's eurofxref XML (daily or historical).
public enum ECBRateParser {
    public enum ParseError: Error, Equatable { case malformed, empty }

    public static func parse(_ data: Data, downloadedAt: Date) throws -> ExchangeRateTable {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw ParseError.malformed }
        guard !delegate.days.isEmpty else { throw ParseError.empty }
        return ExchangeRateTable(days: delegate.days, downloadedAt: downloadedAt)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var days: [String: [String: Decimal]] = [:]
        private var currentDay: String?

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes: [String: String] = [:]) {
            guard elementName == "Cube" else { return }
            if let time = attributes["time"] {
                currentDay = time
                days[time, default: [:]] = days[time] ?? [:]
            } else if let currency = attributes["currency"], let raw = attributes["rate"], let day = currentDay,
                      let rate = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), rate > 0,
                      currency.count == 3 {
                days[day, default: [:]][currency.uppercased()] = rate
            }
        }
    }
}

// MARK: - Download

/// Fetches the ECB tables. The app uses `URLSession`; tests pass saved responses.
public protocol ExchangeRateFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionRateFetcher: ExchangeRateFetching {
    public init() {}

    public func data(from url: URL) async throws -> Data {
        // Ephemeral: no cookies, no cache, no credentials. Nothing about the user is sent.
        let session = URLSession(configuration: .ephemeral)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue(nil, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// MARK: - Service

/// Keeps the last ECB table on disk and refreshes it at most once a day, only
/// when asked for a foreign currency. Never blocks: when the download fails or
/// is switched off, the stored table is used (with its date), or nothing.
public actor ExchangeRateService {
    public static let dailyURL = URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")!
    public static let historyURL = URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml")!
    /// Days kept on disk.
    static let keptDays = 120

    /// What a lookup found.
    public struct Lookup: Sendable, Equatable {
        /// The rate to propose, or nil (then the user types a rate or the euros).
        public var quote: ExchangeRateQuote?
        /// The stored table was used because the download failed or is off.
        public var isFromStoredTable: Bool
        /// When the table used was downloaded.
        public var tableDownloadedAt: Date?
    }

    private let fetcher: any ExchangeRateFetching
    private let fileURL: URL
    private var table: ExchangeRateTable?
    private var loaded = false
    /// Last failed download: no new attempt within `retryDelay` (offline, captive Wi-Fi…).
    private var lastFailure: Date?
    static let retryDelay: TimeInterval = 15 * 60

    public init(fetcher: any ExchangeRateFetching = URLSessionRateFetcher(), fileURL: URL) {
        self.fetcher = fetcher
        self.fileURL = fileURL
    }

    /// `<Application Support>/Bifaz/ecb-rates.json` in the app's own container.
    public static func defaultFileURL() throws -> URL {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
            .appending(path: "Bifaz", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "ecb-rates.json")
    }

    /// The stored table, without any download.
    public func storedTable() -> ExchangeRateTable? {
        loadIfNeeded()
        return table
    }

    /// The rate for `currency` on `date`. Downloads first when allowed and the
    /// stored table is older than a day (or lacks the expense's period).
    public func lookup(_ currency: String, on date: Date, now: Date = .now, allowDownload: Bool) async -> Lookup {
        loadIfNeeded()
        var usedStored = true
        if allowDownload, needsDownload(for: date, now: now) {
            if await download(now: now, includeHistory: wantsHistory(for: date, now: now)) { usedStored = false }
        } else if allowDownload, table != nil {
            usedStored = false // fresh enough
        }
        guard let table else { return Lookup(quote: nil, isFromStoredTable: usedStored, tableDownloadedAt: nil) }
        return Lookup(
            quote: CurrencyConverter.quote(for: currency, on: date, in: table),
            isFromStoredTable: usedStored,
            tableDownloadedAt: table.downloadedAt
        )
    }

    /// Currencies the stored table knows (for the picker).
    public func knownCurrencies() -> [String] {
        loadIfNeeded()
        return table?.currencies ?? []
    }

    func needsDownload(for date: Date, now: Date) -> Bool {
        if let lastFailure, now.timeIntervalSince(lastFailure) < Self.retryDelay { return false }
        guard let table else { return true }
        if now.timeIntervalSince(table.downloadedAt) >= 24 * 3600 { return true }
        // Downloaded today but only the daily table: an older expense needs the history once.
        return wantsHistory(for: date, now: now) && table.days.count <= 1
    }

    func wantsHistory(for date: Date, now: Date) -> Bool {
        (table?.days.count ?? 0) <= 1 || now.timeIntervalSince(date) > 3 * 86_400
    }

    /// Returns true when a fresh table was stored.
    @discardableResult
    func download(now: Date, includeHistory: Bool) async -> Bool {
        do {
            var fresh = try ECBRateParser.parse(try await fetcher.data(from: Self.dailyURL), downloadedAt: now)
            if includeHistory {
                let history = try ECBRateParser.parse(try await fetcher.data(from: Self.historyURL), downloadedAt: now)
                fresh = history.merging(fresh)
            }
            table = ((table?.merging(fresh)) ?? fresh).trimmed(toDays: Self.keptDays)
            save()
            lastFailure = nil
            return true
        } catch {
            lastFailure = now
            return false
        }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        table = try? JSONDecoder().decode(ExchangeRateTable.self, from: data)
    }

    private func save() {
        guard let table, let data = try? JSONEncoder().encode(table) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
