import CoreGraphics
import Foundation
import BifazModels
import os

/// Reads a receipt: OCR on the device, then Apple's model when available,
/// always cross-checked with the rule-based reader (PLAN §4 "Lectura automática").
///
/// Runs off the main thread (every entry point is `async` and nonisolated).
public struct ReceiptReader: Sendable {
    private let useModel: Bool
    private static let logger = Logger(subsystem: "com.dvxlabs.bifaz", category: "reading")

    /// - Parameter useModel: set `false` to force the rule-based reader (tests, low battery).
    public init(useModel: Bool = true) {
        self.useModel = useModel
    }

    /// Whether Apple's model will be used on this device.
    public var usesModel: Bool { useModel && ModelReceiptParser.isAvailable }

    public func read(images: [CGImage], today: Date = .now) async throws -> ReceiptReading {
        var lines: [String] = []
        for image in images { lines += try await ReceiptOCR.lines(in: image) }
        return await read(lines: lines, today: today)
    }

    public func read(pdf data: Data, today: Date = .now) async throws -> ReceiptReading {
        await read(lines: try await ReceiptOCR.lines(inPDF: data), today: today)
    }

    /// Reads already recognised lines (also the entry point for tests).
    public func read(lines: [String], today: Date = .now, calendar: Calendar = .current) async -> ReceiptReading {
        let rules = RuleBasedReceiptParser.parse(lines, today: today, calendar: calendar)
        guard usesModel, !lines.isEmpty else {
            return ReceiptReading(fields: rules, lines: lines, method: .rules)
        }
        do {
            let extraction = try await ModelReceiptParser.extract(from: lines)
            let fields = Self.combine(model: extraction, rules: rules, lines: lines, today: today, calendar: calendar)
            return ReceiptReading(fields: fields, lines: lines, method: .model)
        } catch {
            Self.logger.notice("Model reading failed, using rules: \(String(describing: type(of: error)), privacy: .public)")
            return ReceiptReading(fields: rules, lines: lines, method: .rules)
        }
    }

    // MARK: - Cross-checking

    /// Merges the model's answer with the rules. A model value must appear in
    /// the text; agreement with the rules raises the confidence to high.
    static func combine(
        model: ModelReceiptParser.Extraction,
        rules: ReceiptFields,
        lines: [String],
        today: Date,
        calendar: Calendar
    ) -> ReceiptFields {
        var fields = rules
        let rows = lines.map(RuleBasedReceiptParser.Row.init)
        let amountsInText = Set(rows.flatMap(\.amounts))
        let foldedText = rows.map(\.folded).joined(separator: "\n")

        // Total.
        if let total = model.totalIncludingVAT.flatMap(Self.decimal), amountsInText.contains(total) {
            if let ruled = rules.total {
                if ruled.value == total {
                    fields.total = ReadValue(total, confidence: .high)
                } else if ruled.confidence != .high {
                    fields.total = ReadValue(total, confidence: .medium)
                }
            } else {
                fields.total = ReadValue(total, confidence: .medium)
            }
        }

        // Merchant: the model is better at names; keep it only if printed.
        if let name = model.merchant?.trimmingCharacters(in: .whitespacesAndNewlines), name.count >= 2 {
            let folded = RuleBasedReceiptParser.Row(name).folded
            if foldedText.contains(folded) {
                let ruled = rules.merchant.map { RuleBasedReceiptParser.Row($0.value).folded }
                let agrees = ruled.map { $0.contains(folded) || folded.contains($0) } ?? false
                fields.merchant = ReadValue(
                    RuleBasedReceiptParser.cleanMerchant(name),
                    confidence: agrees ? .high : .medium
                )
            }
        }

        // Date: only a date that is printed and plausible.
        if let iso = model.date, let date = Self.isoDate(iso, calendar: calendar) {
            let printed = rows.flatMap { RuleBasedReceiptParser.dateComponents(in: $0.folded) }
                .compactMap { calendar.date(from: $0) }
                .contains { calendar.isDate($0, inSameDayAs: date) }
            if printed {
                let agrees = rules.date.map { calendar.isDate($0.value, inSameDayAs: date) } ?? false
                if agrees {
                    fields.date = ReadValue(rules.date!.value, confidence: .high)
                } else if rules.date?.confidence != .high {
                    fields.date = ReadValue(date, confidence: .medium)
                }
            }
        }

        // VAT: the rules' table wins; the model fills the gaps.
        if let percent = model.vatRatePercent,
           let rate = VATRate.allCases.map(\.fraction).first(where: { ($0 * 100) == Decimal(percent).rounded(scale: 1) }) {
            if let ruled = fields.vatRate {
                if ruled.value == rate { fields.vatRate = ReadValue(rate, confidence: .high) }
            } else {
                fields.vatRate = ReadValue(rate, confidence: .medium)
                if fields.vatAmount == nil, let total = fields.total?.value {
                    fields.vatAmount = ReadValue(VATCalculator.vatAmount(includedIn: total, rate: rate), confidence: .low)
                }
            }
        }
        if fields.vatAmount == nil, let vat = model.vatAmount.flatMap(Self.decimal), amountsInText.contains(vat) {
            fields.vatAmount = ReadValue(vat, confidence: .medium)
        }
        return fields
    }

    static func decimal(_ text: String) -> Decimal? {
        Decimal(string: text.replacing(",", with: ".").filter { $0.isNumber || $0 == "." },
                locale: Locale(identifier: "en_US_POSIX"))?.rounded(scale: 2)
    }

    static func isoDate(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}
