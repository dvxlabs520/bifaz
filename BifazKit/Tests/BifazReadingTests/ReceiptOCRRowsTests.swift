import CoreGraphics
import Testing
@testable import BifazReading

@Suite("ReceiptOCR.rows")
struct ReceiptOCRRowsTests {
    private func fragment(_ text: String, x: CGFloat, y: CGFloat, height: CGFloat = 0.02) -> ReceiptOCR.Fragment {
        .init(text: text, minX: x, midY: y, height: height)
    }

    @Test("Fragments on one row are joined left to right with two spaces")
    func sameRow() {
        let rows = ReceiptOCR.rows(from: [
            fragment("42,50 €", x: 0.7, y: 0.5),
            fragment("TOTAL TTC", x: 0.1, y: 0.5),
        ])
        #expect(rows == ["TOTAL TTC  42,50 €"])
    }

    @Test("Rows are ordered top to bottom (Vision's origin is bottom-left)")
    func ordering() {
        let rows = ReceiptOCR.rows(from: [
            fragment("bottom", x: 0.1, y: 0.1),
            fragment("top", x: 0.1, y: 0.9),
            fragment("middle", x: 0.1, y: 0.5),
        ])
        #expect(rows == ["top", "middle", "bottom"])
    }

    @Test("Slight skew still groups into one row")
    func skew() {
        // Centres differ by 0.008, under half the 0.02 line height.
        let rows = ReceiptOCR.rows(from: [
            fragment("TOTAL", x: 0.1, y: 0.500),
            fragment("TTC", x: 0.3, y: 0.504),
            fragment("42,50", x: 0.7, y: 0.508),
        ])
        #expect(rows == ["TOTAL  TTC  42,50"])
    }

    @Test("Separate rows stay separate")
    func separateRows() {
        // 0.03 apart with 0.02 tall lines: more than half a line height.
        let rows = ReceiptOCR.rows(from: [
            fragment("LABEL A", x: 0.1, y: 0.53),
            fragment("1,00", x: 0.7, y: 0.53),
            fragment("LABEL B", x: 0.1, y: 0.50),
            fragment("2,00", x: 0.7, y: 0.50),
        ])
        #expect(rows == ["LABEL A  1,00", "LABEL B  2,00"])
    }

    @Test("No fragments, no rows")
    func empty() {
        #expect(ReceiptOCR.rows(from: []).isEmpty)
    }
}
