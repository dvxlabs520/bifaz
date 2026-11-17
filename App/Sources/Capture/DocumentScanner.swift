import SwiftUI
import VisionKit

/// VisionKit's document camera: finds the receipt's edges, crops and
/// straightens it, and returns one image per page.
struct DocumentScanner: UIViewControllerRepresentable {
    /// Called with the scanned pages, or `nil` when cancelled or failed.
    let onFinish: ([CGImage]?) -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([CGImage]?) -> Void

        init(onFinish: @escaping ([CGImage]?) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage }
            onFinish(pages.isEmpty ? nil : pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            Log.app.error("Document camera failed: \(String(describing: type(of: error)), privacy: .public)")
            onFinish(nil)
        }
    }
}
