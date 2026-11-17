import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// Where a receipt comes from.
public enum ReceiptInput: Sendable {
    /// Pages from the document camera (already cropped and straightened by VisionKit).
    case scan([CGImage])
    /// A photo file from the library (JPEG, HEIC, PNG…).
    case photo(Data)
    /// A PDF from Files, Mail or a share.
    case pdf(Data)
}

/// A receipt ready to be stored and attached: the file to keep, its thumbnail
/// and what the reader found.
public struct CapturedReceipt: Sendable {
    public let fileData: Data
    public let typeIdentifier: String
    public let fileExtension: String
    public let thumbnailData: Data?
    public let reading: ReceiptReading
}

public enum ReceiptCapture {
    public enum Failure: Error, Sendable {
        case unreadableImage
        case emptyScan
    }

    /// Normalises the file (photos → JPEG ≤ 2400 px, multi-page scans → PDF),
    /// makes the thumbnail and reads the receipt. Runs off the main thread.
    public static func process(_ input: ReceiptInput, reader: ReceiptReader = ReceiptReader()) async throws -> CapturedReceipt {
        switch input {
        case .scan(let pages):
            guard let first = pages.first else { throw Failure.emptyScan }
            let reading = try await reader.read(images: pages)
            if pages.count == 1, let jpeg = ReceiptImaging.jpegData(first) {
                return CapturedReceipt(
                    fileData: jpeg, typeIdentifier: UTType.jpeg.identifier, fileExtension: "jpg",
                    thumbnailData: ReceiptImaging.thumbnail(for: jpeg, isPDF: false), reading: reading
                )
            }
            guard let pdf = ReceiptImaging.pdfData(from: pages) else { throw Failure.unreadableImage }
            return CapturedReceipt(
                fileData: pdf, typeIdentifier: UTType.pdf.identifier, fileExtension: "pdf",
                thumbnailData: ReceiptImaging.thumbnail(for: pdf, isPDF: true), reading: reading
            )

        case .photo(let data):
            guard let image = ReceiptImaging.image(from: data, maxPixel: ReceiptImaging.storedMaxPixel),
                  let jpeg = ReceiptImaging.jpegData(image) else { throw Failure.unreadableImage }
            let reading = try await reader.read(images: [image])
            return CapturedReceipt(
                fileData: jpeg, typeIdentifier: UTType.jpeg.identifier, fileExtension: "jpg",
                thumbnailData: ReceiptImaging.thumbnail(for: jpeg, isPDF: false), reading: reading
            )

        case .pdf(let data):
            let reading = try await reader.read(pdf: data)
            return CapturedReceipt(
                fileData: data, typeIdentifier: UTType.pdf.identifier, fileExtension: "pdf",
                thumbnailData: ReceiptImaging.thumbnail(for: data, isPDF: true), reading: reading
            )
        }
    }
}
