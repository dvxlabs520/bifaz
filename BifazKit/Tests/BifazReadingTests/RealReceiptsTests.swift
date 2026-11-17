import Foundation
import ImageIO
import Testing
import BifazModels
@testable import BifazReading

/// Reads the user's real receipts in `TestData/Real/` (ignored by git: personal
/// documents) and reports, field by field, what the rules and Apple's model read.
///
/// Opt-in: the suite is skipped while the folder has no documents. Put JPEG,
/// PNG, HEIC or PDF files in it, optionally an `expected.json` such as
/// `{"ticket-monoprix.jpg": {"merchant": "Monoprix", "date": "2026-11-12",
///   "total": "27.27", "vatRates": ["0.20", "0.055"], "vatAmount": "3.08"}}`,
/// then run `Tools/receipts/read-real.sh`. The report is written to
/// `TestData/Real/report.md` and printed in the test log. With `expected.json`,
/// every wrong field is also recorded as a test issue.
@Suite("Real receipts (TestData/Real)", .enabled(if: RealReceipts.hasDocuments, "No documents in TestData/Real"), .serialized)
struct RealReceiptsTests {
    @Test("Read every real receipt with the rules and with Apple's model")
    func readRealReceipts() async throws {
        let expected = RealReceipts.expected()
        var report = RealReceipts.Report()
        for file in RealReceipts.documents() {
            let lines = try await RealReceipts.lines(of: file)
            let rules = await ReceiptReader(useModel: false).read(lines: lines)
            let model = ReceiptReader().usesModel ? await ReceiptReader(useModel: true).read(lines: lines) : nil
            report.add(file: file.lastPathComponent, rules: rules, model: model, expected: expected[file.lastPathComponent])
        }
        let text = report.markdown()
        print(text)
        try text.write(to: RealReceipts.folder.appending(path: "report.md"), atomically: true, encoding: .utf8)
        for failure in report.failures {
            Issue.record(Comment(rawValue: failure))
        }
    }
}

enum RealReceipts {
    static let folder: URL = repositoryRoot.appending(path: "TestData/Real", directoryHint: .isDirectory)
    static let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "pdf"]

    static var hasDocuments: Bool { !documents().isEmpty }

    static func documents() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    struct Expected: Decodable {
        var merchant: String?
        var date: String?
        var total: String?
        var vatRates: [String]?
        var vatAmount: String?
    }

    static func expected() -> [String: Expected] {
        guard let data = try? Data(contentsOf: folder.appending(path: "expected.json")) else { return [:] }
        return (try? JSONDecoder().decode([String: Expected].self, from: data)) ?? [:]
    }

    static func lines(of file: URL) async throws -> [String] {
        let data = try Data(contentsOf: file)
        if file.pathExtension.lowercased() == "pdf" { return try await ReceiptOCR.lines(inPDF: data) }
        guard let image = ReceiptImaging.image(from: data, maxPixel: ReceiptImaging.storedMaxPixel) else {
            throw ReceiptCapture.Failure.unreadableImage
        }
        return try await ReceiptOCR.lines(in: image)
    }

    /// Field-by-field comparison, scored separately for rules and model.
    struct Report {
        private var rows: [String] = []
        private(set) var failures: [String] = []
        private var score: [String: (rules: Int, model: Int, total: Int)] = [:]
        private var modelRuns = 0

        private static let fields = ["merchant", "date", "total", "vatRates", "vatAmount"]

        mutating func add(file: String, rules: ReceiptReading, model: ReceiptReading?, expected: Expected?) {
            if model != nil { modelRuns += 1 }
            rows.append("\n### \(file)\n\n| Field | Rules | Apple model | Expected |\n|---|---|---|---|")
            for field in Self.fields {
                let ruled = Self.value(field, of: rules.fields)
                let modelled = model.map { Self.value(field, of: $0.fields) } ?? "—"
                let wanted = Self.expectedValue(field, in: expected)
                rows.append("| \(field) | \(ruled) | \(modelled) | \(wanted ?? "—") |")
                guard let wanted else { continue }
                var entry = score[field] ?? (0, 0, 0)
                entry.total += 1
                if Self.matches(field, ruled, wanted) { entry.rules += 1 } else {
                    failures.append("\(file) · \(field) · rules read \(ruled), expected \(wanted)")
                }
                if model != nil {
                    if Self.matches(field, modelled, wanted) { entry.model += 1 } else {
                        failures.append("\(file) · \(field) · model read \(modelled), expected \(wanted)")
                    }
                }
                score[field] = entry
            }
            rows.append("\nRecognised lines: \(rules.lines.count). Method with model: \(model?.method.rawValue ?? "not available").")
        }

        func markdown() -> String {
            var text = "# Real receipts — reading report\n\nDocuments: \(rows.filter { $0.hasPrefix("\n### ") }.count). "
            text += "Apple's model: \(modelRuns > 0 ? "available" : "not available on this device").\n"
            if !score.isEmpty {
                text += "\n| Field | Rules | Apple model |\n|---|---|---|\n"
                for field in Self.fields {
                    guard let entry = score[field] else { continue }
                    let model = modelRuns > 0 ? "\(entry.model)/\(entry.total)" : "—"
                    text += "| \(field) | \(entry.rules)/\(entry.total) | \(model) |\n"
                }
            }
            return text + rows.joined(separator: "\n") + "\n"
        }

        static func value(_ field: String, of fields: ReceiptFields) -> String {
            switch field {
            case "merchant": return fields.merchant.map { "\($0.value) (\($0.confidence.rawValue))" } ?? "—"
            case "date": return fields.date.map { "\($0.value.formatted(.iso8601.year().month().day())) (\($0.confidence.rawValue))" } ?? "—"
            case "total": return fields.total.map { "\($0.value) (\($0.confidence.rawValue))" } ?? "—"
            case "vatRates":
                let rates = fields.vatLines.isEmpty ? fields.vatRate.map { [$0.value] } ?? [] : fields.vatLines.map(\.rate)
                return rates.isEmpty ? "—" : rates.map { "\($0)" }.sorted().joined(separator: ", ")
            case "vatAmount": return fields.vatAmount.map { "\($0.value) (\($0.confidence.rawValue))" } ?? "—"
            default: return "—"
            }
        }

        static func expectedValue(_ field: String, in expected: Expected?) -> String? {
            guard let expected else { return nil }
            switch field {
            case "merchant": return expected.merchant
            case "date": return expected.date
            case "total": return expected.total
            case "vatRates": return expected.vatRates.map { $0.sorted().joined(separator: ", ") }
            case "vatAmount": return expected.vatAmount
            default: return nil
            }
        }

        /// Read values carry " (confidence)"; compare the value part only.
        static func matches(_ field: String, _ read: String, _ wanted: String) -> Bool {
            let value = read.components(separatedBy: " (").first ?? read
            func fold(_ text: String) -> String {
                text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            }
            switch field {
            case "merchant": return fold(value).contains(fold(wanted)) || fold(wanted).contains(fold(value))
            case "vatRates":
                let normalize = { (text: String) in Set(text.split(separator: ",").compactMap { Decimal(string: $0.trimmingCharacters(in: .whitespaces)) }) }
                return normalize(value) == normalize(wanted)
            case "total", "vatAmount": return Decimal(string: value) == Decimal(string: wanted)
            default: return value == wanted
            }
        }
    }
}
