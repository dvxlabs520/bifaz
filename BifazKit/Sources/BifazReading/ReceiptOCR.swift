import CoreGraphics
import Foundation
import PDFKit
import Vision

/// Turns receipt images and PDFs into text lines, top to bottom.
///
/// Vision returns one observation per text fragment; on receipts the label
/// ("TOTAL TTC") and its amount are separate fragments on the same printed
/// row. `rows(from:)` groups fragments by row and joins them left to right
/// with two spaces, which is what `RuleBasedReceiptParser` expects.
public enum ReceiptOCR {
    public enum Failure: Error, Sendable {
        case unreadablePDF
    }

    /// Recognises the text of one image (on device, accurate, French first).
    public static func lines(in image: CGImage) async throws -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [
            Locale.Language(identifier: "fr-FR"),
            Locale.Language(identifier: "en-US"),
            Locale.Language(identifier: "es-ES"),
        ]
        let observations = try await request.perform(on: image)
        let fragments = observations.compactMap { observation -> Fragment? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox.cgRect
            return Fragment(text: text, minX: box.minX, midY: box.midY, height: box.height)
        }
        return rows(from: fragments)
    }

    /// Text of a PDF: its embedded text when it has some (e-invoices), else OCR
    /// of the first pages rendered as images (scanned PDFs).
    public static func lines(inPDF data: Data, maxPages: Int = 3) async throws -> [String] {
        guard let document = PDFDocument(data: data) else { throw Failure.unreadablePDF }
        let pageCount = min(document.pageCount, maxPages)
        let embedded = (0..<pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        let embeddedLines = embedded
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if embeddedLines.count >= 3 { return embeddedLines }

        var lines: [String] = []
        for index in 0..<pageCount {
            guard let page = document.page(at: index), let image = ReceiptImaging.render(page) else { continue }
            lines += try await self.lines(in: image)
        }
        return lines
    }

    // MARK: - Row reconstruction

    struct Fragment: Sendable {
        let text: String
        /// Normalised coordinates, origin bottom-left (Vision convention).
        let minX: CGFloat
        let midY: CGFloat
        let height: CGFloat
    }

    /// Groups fragments whose vertical centres are within half a line height,
    /// then orders rows top to bottom and fragments left to right.
    static func rows(from fragments: [Fragment]) -> [String] {
        let sorted = fragments.sorted { $0.midY > $1.midY }
        var rows: [[Fragment]] = []
        for fragment in sorted {
            if let last = rows.last?.last,
               abs(last.midY - fragment.midY) < max(last.height, fragment.height) * 0.5 {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return rows.map { row in
            row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: "  ")
        }
    }
}
