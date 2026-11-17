import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Image work for receipts: downsampling, JPEG encoding, thumbnails and PDF
/// rendering, with ImageIO and Core Graphics only (no UIKit, safe off the main thread).
public enum ReceiptImaging {
    /// Longest side of a stored receipt photo: enough to read a thermal ticket, small on disk.
    public static let storedMaxPixel = 2400
    /// Longest side of a thumbnail (lists show it at 44 pt).
    public static let thumbnailMaxPixel = 360

    /// Decodes an image file (JPEG, HEIC, PNG…), downsampled to `maxPixel`, honouring EXIF orientation.
    public static func image(from data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// JPEG data of an image.
    public static func jpegData(_ image: CGImage, quality: Double = 0.8) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// Renders a PDF page to an image about `maxPixel` on its longest side, on white.
    public static func render(_ page: PDFPage, maxPixel: CGFloat = 2400) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = maxPixel / max(bounds.width, bounds.height)
        let width = Int(bounds.width * scale), height = Int(bounds.height * scale)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    /// Builds a multi-page PDF from scanned pages (document camera).
    public static func pdfData(from pages: [CGImage]) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }
        for page in pages {
            // Points at 72 dpi from a ~200 dpi scan keeps A4 pages near A4 size.
            var box = CGRect(x: 0, y: 0, width: CGFloat(page.width) * 72 / 200, height: CGFloat(page.height) * 72 / 200)
            context.beginPage(mediaBox: &box)
            context.draw(page, in: box)
            context.endPage()
        }
        context.closePDF()
        return data as Data
    }

    /// Thumbnail JPEG for any stored receipt (image or PDF).
    public static func thumbnail(for data: Data, isPDF: Bool) -> Data? {
        let image: CGImage?
        if isPDF {
            image = PDFDocument(data: data)?.page(at: 0).flatMap { render($0, maxPixel: CGFloat(thumbnailMaxPixel)) }
        } else {
            image = self.image(from: data, maxPixel: thumbnailMaxPixel)
        }
        return image.flatMap { jpegData($0, quality: 0.7) }
    }
}
