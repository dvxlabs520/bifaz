import Foundation
import Testing
@testable import BifazModels

@Suite("Exchange rates")
struct ExchangeRatesTests {
    static func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "xml", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    static func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        parisDate(year, month, day, hour: hour)
    }

    static func table() throws -> ExchangeRateTable {
        try ECBRateParser.parse(fixture("eurofxref-hist-90d"), downloadedAt: day(2026, 11, 17, hour: 17))
    }

    // MARK: Parsing

    @Test("The daily table parses (single quotes)")
    func parseDaily() throws {
        let table = try ECBRateParser.parse(Self.fixture("eurofxref-daily"), downloadedAt: .now)
        #expect(table.days.keys.sorted() == ["2026-11-17"])
        #expect(table.days["2026-11-17"]?["USD"] == decimal("1.0989"))
        #expect(table.days["2026-11-17"]?["JPY"] == decimal("175.05"))
        #expect(table.currencies.contains("GBP") && table.currencies.count >= 29)
    }

    @Test("The 90-day table parses (double quotes, one line)")
    func parseHistory() throws {
        let table = try Self.table()
        #expect(table.days.count == 64)
        #expect(table.days["2026-11-16"]?["USD"] == decimal("1.1014"))
        #expect(table.days["2026-08-20"]?["USD"] == decimal("1.1681"))
    }

    @Test("Garbage and empty answers are refused")
    func parseErrors() {
        #expect(throws: ECBRateParser.ParseError.malformed) { try ECBRateParser.parse(Data("<html><body>".utf8), downloadedAt: .now) }
        #expect(throws: ECBRateParser.ParseError.empty) { try ECBRateParser.parse(Data("<a></a>".utf8), downloadedAt: .now) }
    }

    // MARK: Choosing a rate

    @Test("The expense's day, or the last business day before it, is the ECB rate")
    func quoteSameDay() throws {
        let table = try Self.table()
        let monday = try #require(CurrencyConverter.quote(for: "USD", on: Self.day(2026, 11, 16), in: table))
        #expect(monday.rate == decimal("1.1014") && monday.source == .ecb)
        // Sunday 15 → Friday 13.
        let sunday = try #require(CurrencyConverter.quote(for: "USD", on: Self.day(2026, 11, 15), in: table))
        #expect(sunday.rate == decimal("1.1052") && sunday.source == .ecb)
        #expect(CurrencyConverter.dayKey(sunday.date) == "2026-11-13")
        // Late in the evening in Paris is still that day.
        let evening = try #require(CurrencyConverter.quote(for: "USD", on: Self.day(2026, 11, 16, hour: 23), in: table))
        #expect(evening.rate == decimal("1.1014"))
    }

    @Test("Outside the table: the closest day, marked approximate")
    func quoteApproximate() throws {
        let table = try Self.table()
        let old = try #require(CurrencyConverter.quote(for: "USD", on: Self.day(2026, 6, 1), in: table))
        #expect(old.rate == decimal("1.1681") && old.source == .ecbApproximate)
        let future = try #require(CurrencyConverter.quote(for: "USD", on: Self.day(2026, 11, 25), in: table))
        #expect(future.rate == decimal("1.0989") && future.source == .ecbApproximate)
        let soon = try #require(CurrencyConverter.quote(for: "USD", on: Self.day(2026, 11, 19), in: table))
        #expect(soon.source == .ecb)
        #expect(CurrencyConverter.quote(for: "XAF", on: Self.day(2026, 11, 16), in: table) == nil)
    }

    // MARK: Converting

    @Test("Euros at a rate, half up to the cent", arguments: [
        ("48.00", "1.0989", "43.68"), ("0.01", "1.0989", "0.01"), ("100", "175.05", "0.57"),
        ("1", "0.83305", "1.20"), ("9999999.99", "20077.73", "498.06"), ("0.005", "1", "0.01"), ("12", "0", "0"),
    ])
    func euros(amount: String, rate: String, expected: String) {
        #expect(CurrencyConverter.euros(for: decimal(amount), rate: decimal(rate)) == decimal(expected))
    }

    @Test("The rate implied by the euros the bank charged")
    func impliedRate() {
        #expect(CurrencyConverter.impliedRate(amount: 48, euros: decimal("43.68")) == decimal("1.0989010989"))
        #expect(CurrencyConverter.impliedRate(amount: 48, euros: 0) == nil)
        // Converting back with the implied rate gives the typed euros.
        for euros in ["0.01", "1.00", "43.68", "1234.56"] {
            let rate = CurrencyConverter.impliedRate(amount: 48, euros: decimal(euros))!
            #expect(CurrencyConverter.euros(for: 48, rate: rate) == decimal(euros))
        }
    }

    // MARK: Service

    actor FakeFetcher: ExchangeRateFetching {
        var calls: [URL] = []
        var failing = false
        func setFailing(_ value: Bool) { failing = value }
        func data(from url: URL) async throws -> Data {
            calls.append(url)
            if failing { throw URLError(.notConnectedToInternet) }
            return try ExchangeRatesTests.fixture(url == ExchangeRateService.historyURL ? "eurofxref-hist-90d" : "eurofxref-daily")
        }
    }

    static func tempFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "bifaz-rates-\(UUID().uuidString).json")
    }

    @Test("Downloads once a day, keeps the table, and uses it offline")
    func serviceCaching() async throws {
        let fetcher = FakeFetcher()
        let file = Self.tempFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let service = ExchangeRateService(fetcher: fetcher, fileURL: file)
        let now = Self.day(2026, 11, 17, hour: 18)

        let first = await service.lookup("USD", on: Self.day(2026, 11, 2), now: now, allowDownload: true)
        #expect(first.quote?.source == .ecb)
        #expect(first.isFromStoredTable == false)
        #expect(await fetcher.calls.count == 2) // daily + 90 days (empty table)

        _ = await service.lookup("GBP", on: now, now: now.addingTimeInterval(3600), allowDownload: true)
        #expect(await fetcher.calls.count == 2) // same day: nothing

        // A new launch reads the stored table without the network.
        let offline = ExchangeRateService(fetcher: fetcher, fileURL: file)
        let stored = await offline.lookup("USD", on: Self.day(2026, 11, 16), now: now, allowDownload: false)
        #expect(stored.quote?.rate == decimal("1.1014"))
        #expect(stored.isFromStoredTable)
        #expect(stored.tableDownloadedAt == now)
        #expect(await fetcher.calls.count == 2)

        // Next day: one new download.
        _ = await service.lookup("USD", on: now, now: now.addingTimeInterval(25 * 3600), allowDownload: true)
        #expect(await fetcher.calls.count >= 3)
    }

    @Test("A failed download falls back to the stored table and does not retry at once")
    func serviceFailure() async throws {
        let fetcher = FakeFetcher()
        let file = Self.tempFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let service = ExchangeRateService(fetcher: fetcher, fileURL: file)
        let now = Self.day(2026, 11, 17, hour: 18)
        _ = await service.lookup("USD", on: now, now: now, allowDownload: true)
        await fetcher.setFailing(true)
        let tomorrow = now.addingTimeInterval(26 * 3600)
        let lookup = await service.lookup("USD", on: tomorrow, now: tomorrow, allowDownload: true)
        #expect(lookup.isFromStoredTable)
        #expect(lookup.quote?.rate == decimal("1.0989"))
        #expect(lookup.tableDownloadedAt == now)
        let calls = await fetcher.calls.count
        _ = await service.lookup("USD", on: tomorrow, now: tomorrow.addingTimeInterval(60), allowDownload: true)
        #expect(await fetcher.calls.count == calls)
    }

    @Test("Nothing stored and no network: no rate (the user types one)")
    func serviceNothing() async {
        let fetcher = FakeFetcher()
        await fetcher.setFailing(true)
        let file = Self.tempFile()
        let service = ExchangeRateService(fetcher: fetcher, fileURL: file)
        let lookup = await service.lookup("USD", on: .now, allowDownload: true)
        #expect(lookup.quote == nil)
        let off = await ExchangeRateService(fetcher: fetcher, fileURL: Self.tempFile()).lookup("USD", on: .now, allowDownload: false)
        #expect(off.quote == nil)
    }
}
