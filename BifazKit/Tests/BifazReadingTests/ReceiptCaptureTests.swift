import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import BifazReading

@Suite("ReceiptCapture.process")
struct ReceiptCaptureTests {
    private let reader = ReceiptReader(useModel: false)

    private func maxPixel(of data: Data) -> Int? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return max(width, height)
    }

    @Test("A photo becomes a JPEG with a small thumbnail and a reading")
    func photo() async throws {
        let png = try renderedReceiptData("monoprix_courses")
        let captured = try await ReceiptCapture.process(.photo(png), reader: reader)

        #expect(captured.fileExtension == "jpg")
        #expect(captured.typeIdentifier == "public.jpeg")
        #expect(Array(captured.fileData.prefix(2)) == [0xFF, 0xD8], "not a JPEG")
        let thumbnail = try #require(captured.thumbnailData)
        let side = try #require(maxPixel(of: thumbnail))
        #expect(side <= ReceiptImaging.thumbnailMaxPixel && side <= 360)
        #expect(!captured.reading.lines.isEmpty, "OCR returned no text (Vision unavailable?)")
        #expect(!captured.reading.fields.isEmpty)
    }

    @Test("An unreadable photo throws")
    func badPhoto() async {
        await #expect(throws: ReceiptCapture.Failure.self) {
            _ = try await ReceiptCapture.process(.photo(Data("not an image".utf8)), reader: reader)
        }
    }

    @Test("A PDF keeps its data and gets a thumbnail")
    func pdf() async throws {
        let data = try renderedReceiptData("sncf_eticket", fileExtension: "pdf")
        let captured = try await ReceiptCapture.process(.pdf(data), reader: reader)

        #expect(captured.fileData == data)
        #expect(captured.fileExtension == "pdf")
        #expect(captured.typeIdentifier == "com.adobe.pdf")
        let thumbnail = try #require(captured.thumbnailData)
        #expect(try #require(maxPixel(of: thumbnail)) <= 360)
    }

    @Test("A two-page scan becomes a two-page PDF")
    func scanTwoPages() async throws {
        let pages = [try renderedReceiptImage("monoprix_courses"), try renderedReceiptImage("pharmacie_centre")]
        let captured = try await ReceiptCapture.process(.scan(pages), reader: reader)

        #expect(captured.fileExtension == "pdf")
        let document = try #require(PDFDocument(data: captured.fileData))
        #expect(document.pageCount == 2)
        #expect(captured.thumbnailData != nil)
    }

    @Test("A one-page scan becomes a JPEG")
    func scanOnePage() async throws {
        let captured = try await ReceiptCapture.process(.scan([try renderedReceiptImage("monoprix_courses")]), reader: reader)
        #expect(captured.fileExtension == "jpg")
        #expect(captured.thumbnailData != nil)
    }

    @Test("An empty scan throws")
    func emptyScan() async {
        await #expect(throws: ReceiptCapture.Failure.self) {
            _ = try await ReceiptCapture.process(.scan([]), reader: reader)
        }
    }
}
