import CoreGraphics
import Foundation
import ImageIO
import Testing
import BifazModels
@testable import BifazReading

// MARK: - Test assets

/// `GastosApp/` (this file lives in `GastosApp/BifazKit/Tests/BifazReadingTests/`).
let repositoryRoot: URL = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()

func renderedReceiptURL(_ name: String, fileExtension: String = "png") -> URL {
    repositoryRoot.appending(path: "TestData/Receipts/\(name).\(fileExtension)")
}

func renderedReceiptData(_ name: String, fileExtension: String = "png") throws -> Data {
    try Data(contentsOf: renderedReceiptURL(name, fileExtension: fileExtension))
}

/// Full-size decode with ImageIO.
func decodeImage(_ data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func renderedReceiptImage(_ name: String) throws -> CGImage {
    let data = try renderedReceiptData(name)
    return try #require(decodeImage(data), "cannot decode \(name).png")
}

// MARK: - Comparison with the fixture's expectations

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
}()

let endToEndToday: Date = paris.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12))!

private func fold(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
}

private func dec(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))! }

private func day(_ text: String) -> Date {
    let parts = text.split(separator: "-").compactMap { Int($0) }
    return paris.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
}

enum ReadField: String, CaseIterable, Sendable {
    case merchant, date, total, vatRates, vatAmount
}

struct FieldCheck: Sendable {
    let field: ReadField
    let ok: Bool
    let detail: String
}

/// One check per field the fixture expects.
func checks(for fixture: ReceiptFixture, against fields: ReceiptFields) -> [FieldCheck] {
    var result: [FieldCheck] = []
    let expected = fixture.expected
    if let merchant = expected.merchant {
        let actual = fields.merchant?.value
        let ok = actual.map { fold($0).contains(fold(merchant)) || fold(merchant).contains(fold($0)) } ?? false
        result.append(FieldCheck(field: .merchant, ok: ok, detail: "expected \(merchant), got \(actual ?? "nil")"))
    }
    if let date = expected.date {
        let actual = fields.date?.value
        let ok = actual.map { paris.isDate($0, inSameDayAs: day(date)) } ?? false
        result.append(FieldCheck(field: .date, ok: ok, detail: "expected \(date), got \(actual.map { "\($0)" } ?? "nil")"))
    }
    if let total = expected.total {
        let actual = fields.total?.value
        result.append(FieldCheck(field: .total, ok: actual == dec(total), detail: "expected \(total), got \(actual.map { "\($0)" } ?? "nil")"))
    }
    if let rates = expected.vatRates {
        var actual = Set(fields.vatLines.map(\.rate))
        if actual.isEmpty, let single = fields.vatRate { actual.insert(single.value) }
        let wanted = Set(rates.map(dec))
        result.append(FieldCheck(field: .vatRates, ok: actual == wanted, detail: "expected \(wanted.sorted()), got \(actual.sorted())"))
    }
    if let vat = expected.vatAmount {
        let actual = fields.vatAmount?.value
        result.append(FieldCheck(field: .vatAmount, ok: actual == dec(vat), detail: "expected \(vat), got \(actual.map { "\($0)" } ?? "nil")"))
    }
    return result
}

func numbered(_ lines: [String], limit: Int = 70) -> String {
    let shown = lines.prefix(limit).enumerated().map { "  \($0.offset + 1): \($0.element)" }
    return shown.joined(separator: "\n") + (lines.count > limit ? "\n  … (\(lines.count - limit) more)" : "")
}

// MARK: - Reading cache (each receipt is read once per mode)

struct EndToEndResult: Sendable {
    let fixture: ReceiptFixture
    let reading: ReceiptReading?
    let error: String?
    var checks: [FieldCheck] { reading.map { ReadingChecks.make(fixture, $0) } ?? [] }
}

enum ReadingChecks {
    static func make(_ fixture: ReceiptFixture, _ reading: ReceiptReading) -> [FieldCheck] {
        checks(for: fixture, against: reading.fields)
    }
}

actor ReadingCache {
    static let rules = ReadingCache(useModel: false)
    static let model = ReadingCache(useModel: true)

    private let useModel: Bool
    private var results: [String: EndToEndResult] = [:]

    init(useModel: Bool) { self.useModel = useModel }

    func result(for fixture: ReceiptFixture) async -> EndToEndResult {
        if let cached = results[fixture.name] { return cached }
        let reader = ReceiptReader(useModel: useModel)
        let result: EndToEndResult
        do {
            let reading: ReceiptReading
            if fixture.kind == "pdf" {
                let data = try renderedReceiptData(fixture.name, fileExtension: "pdf")
                reading = try await reader.read(pdf: data, today: endToEndToday)
            } else {
                let image = try renderedReceiptImage(fixture.name)
                reading = try await reader.read(images: [image], today: endToEndToday)
            }
            result = EndToEndResult(fixture: fixture, reading: reading, error: nil)
        } catch {
            result = EndToEndResult(fixture: fixture, reading: nil, error: "\(error)")
        }
        results[fixture.name] = result
        return result
    }
}

/// Every fixture that has a rendered file. The SNCF e-ticket exists as PNG and as PDF: the PNG
/// goes through image OCR, the PDF (`kind == "pdf"` fixture is the same receipt) through `read(pdf:)`.
let endToEndFixtures: [ReceiptFixture] = ReceiptFixture.all

private func fileExists(_ fixture: ReceiptFixture) -> Bool {
    let ext = fixture.kind == "pdf" ? "pdf" : "png"
    return FileManager.default.fileExists(atPath: renderedReceiptURL(fixture.name, fileExtension: ext).path(percentEncoded: false))
}

private func verify(_ result: EndToEndResult, mode: String) {
    let fixture = result.fixture
    if let error = result.error {
        Issue.record("[\(mode)] \(fixture.name): reading threw \(error)")
        return
    }
    guard let reading = result.reading else { return }
    if reading.lines.isEmpty {
        Issue.record("[\(mode)] \(fixture.name): the OCR returned no text at all. Vision text recognition may be unavailable in this simulator (or the file is not readable).")
        return
    }
    let failed = result.checks.filter { !$0.ok }
    for check in failed {
        Issue.record("[\(mode)] \(fixture.name) · \(check.field.rawValue): \(check.detail)\nOCR lines (method \(reading.method.rawValue)):\n\(numbered(reading.lines))")
    }
}

private func scoreboard(_ results: [EndToEndResult], title: String) -> (text: String, perField: [ReadField: (ok: Int, total: Int)]) {
    var perField: [ReadField: (ok: Int, total: Int)] = [:]
    for result in results {
        for check in result.checks {
            let current = perField[check.field] ?? (0, 0)
            perField[check.field] = (current.ok + (check.ok ? 1 : 0), current.total + 1)
        }
    }
    var text = "=== Reading scoreboard: \(title) (\(results.count) receipts) ===\n"
    for field in ReadField.allCases {
        guard let score = perField[field] else { continue }
        text += "  \(field.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \(score.ok)/\(score.total)\n"
    }
    let vat = [ReadField.vatRates, .vatAmount].compactMap { perField[$0] }
    text += "  VAT (rates + amount pooled) \(vat.map(\.ok).reduce(0, +))/\(vat.map(\.total).reduce(0, +))\n"
    let failing = results.filter { $0.checks.contains { !$0.ok } || $0.reading?.lines.isEmpty ?? true }
    for result in failing {
        let bad = result.checks.filter { !$0.ok }.map { "\($0.field.rawValue) (\($0.detail))" }.joined(separator: "; ")
        text += "  FAIL \(result.fixture.name): \(bad.isEmpty ? (result.error ?? "no text") : bad)\n"
    }
    return (text, perField)
}

private func verifyBar(_ results: [EndToEndResult], title: String) {
    let board = scoreboard(results, title: title)
    print(board.text)
    Attachment.record(board.text, named: "scoreboard-\(title).txt")
    for field in [ReadField.merchant, .date, .total] {
        if let score = board.perField[field] {
            #expect(score.ok == score.total, "\(title): \(field.rawValue) must be correct on every receipt, got \(score.ok)/\(score.total)")
        }
    }
    let vat = [ReadField.vatRates, .vatAmount].compactMap { board.perField[$0] }
    let ok = vat.map(\.ok).reduce(0, +), total = vat.map(\.total).reduce(0, +)
    #expect(total > 0 && Double(ok) >= 0.9 * Double(total), "\(title): VAT must be correct on at least 90 %, got \(ok)/\(total)")
}

// MARK: - Rules only (Vision OCR on the rendered receipts)

@Suite("End to end, rules only (Vision OCR)")
struct EndToEndRulesTests {
    @Test("Rendered files are present")
    func assets() {
        let missing = endToEndFixtures.filter { !fileExists($0) }.map(\.name)
        #expect(missing.isEmpty, "No rendered file in TestData/Receipts for: \(missing)")
        #expect(endToEndFixtures.count >= 20)
    }

    @Test("Receipt read from its image", arguments: endToEndFixtures.filter { $0.kind != "pdf" })
    func image(_ fixture: ReceiptFixture) async {
        verify(await ReadingCache.rules.result(for: fixture), mode: "rules")
    }

    @Test("SNCF e-ticket read from the PDF", arguments: endToEndFixtures.filter { $0.kind == "pdf" })
    func pdf(_ fixture: ReceiptFixture) async {
        verify(await ReadingCache.rules.result(for: fixture), mode: "rules/pdf")
    }

    @Test("Scoreboard and bar: merchant, date, total on every receipt, VAT on at least 90 %")
    func bar() async {
        var results: [EndToEndResult] = []
        for fixture in endToEndFixtures { results.append(await ReadingCache.rules.result(for: fixture)) }
        verifyBar(results, title: "rules")
    }
}

// MARK: - With Apple's model

private let modelAvailable = ReceiptReader().usesModel

@Suite(
    "End to end, with Apple's model",
    .enabled(if: modelAvailable, "Apple's on-device model is not available here (no Apple Intelligence in this simulator or device)"),
    .serialized
)
struct EndToEndModelTests {
    @Test("Receipt read from its image", arguments: endToEndFixtures.filter { $0.kind != "pdf" })
    func image(_ fixture: ReceiptFixture) async {
        verify(await ReadingCache.model.result(for: fixture), mode: "model")
    }

    @Test("SNCF e-ticket read from the PDF", arguments: endToEndFixtures.filter { $0.kind == "pdf" })
    func pdf(_ fixture: ReceiptFixture) async {
        verify(await ReadingCache.model.result(for: fixture), mode: "model/pdf")
    }

    @Test("Scoreboard and bar with the model")
    func bar() async {
        var results: [EndToEndResult] = []
        for fixture in endToEndFixtures { results.append(await ReadingCache.model.result(for: fixture)) }
        verifyBar(results, title: "model")
    }
}
