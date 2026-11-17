import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import BifazModels
import BifazReading
import BifazDesign

/// Where the user wants to take a receipt from.
enum CaptureSource: String, Identifiable {
    case scanner, photo, pdf
    var id: String { rawValue }
}

extension EnvironmentValues {
    /// The receipt file store (nil only if the App Group is unavailable).
    @Entry var receiptStore: ReceiptStore?
}

extension View {
    /// Presents the scanner, the photo picker or the file importer for `source`,
    /// shows "Reading…" while the receipt is processed off the main thread,
    /// and hands back the captured receipt.
    func receiptCapture(
        source: Binding<CaptureSource?>,
        onCaptured: @escaping (CapturedReceipt) -> Void
    ) -> some View {
        modifier(ReceiptCaptureModifier(source: source, onCaptured: onCaptured))
    }
}

private struct ReceiptCaptureModifier: ViewModifier {
    @Binding var source: CaptureSource?
    let onCaptured: (CapturedReceipt) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var failed = false

    private var scannerBinding: Binding<Bool> {
        Binding { source == .scanner } set: { if !$0 { source = nil } }
    }
    private var photoBinding: Binding<Bool> {
        Binding { source == .photo } set: { if !$0 { source = nil } }
    }
    private var pdfBinding: Binding<Bool> {
        Binding { source == .pdf } set: { if !$0 { source = nil } }
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: scannerBinding) {
                DocumentScanner { pages in
                    source = nil
                    if let pages { process(.scan(pages)) }
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: photoBinding, selection: $photoItem, matching: .images, preferredItemEncoding: .current)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { failed = true; return }
                    process(.photo(data))
                }
            }
            .fileImporter(isPresented: pdfBinding, allowedContentTypes: [.pdf, .image]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { failed = true; return }
                let isPDF = UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) ?? false
                process(isPDF ? .pdf(data) : .photo(data))
            }
            .overlay {
                if isProcessing { ReadingOverlay() }
            }
            .alert("capture.error.title", isPresented: $failed) {
                Button("capture.error.ok") {}
            } message: {
                Text("capture.error.message")
            }
    }

    /// Debug builds accept `-BifazDisableModel YES` to exercise the rules-only path.
    private static var modelAllowed: Bool {
        #if DEBUG
        !UserDefaults.standard.bool(forKey: "BifazDisableModel")
        #else
        true
        #endif
    }

    private func process(_ input: ReceiptInput) {
        isProcessing = true
        Task {
            do {
                let start = ContinuousClock.now
                let captured = try await ReceiptCapture.process(input, reader: ReceiptReader(useModel: Self.modelAllowed))
                let seconds = (ContinuousClock.now - start).components.seconds
                Log.app.info("""
                    Receipt read in \(seconds, privacy: .public) s · method \(captured.reading.method.rawValue, privacy: .public) \
                    · model \(captured.reading.modelOutcome.rawValue, privacy: .public)
                    """)
                isProcessing = false
                onCaptured(captured)
            } catch {
                Log.app.error("Receipt capture failed: \(String(describing: type(of: error)), privacy: .public)")
                isProcessing = false
                failed = true
            }
        }
    }
}

/// "Reading your receipt…" over the current screen.
private struct ReadingOverlay: View {
    var body: some View {
        ZStack {
            Color.bifazPaper.opacity(0.92).ignoresSafeArea()
            VStack(spacing: BifazSpacing.m) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.bifazInk)
                Text("capture.reading")
                    .font(.bifazHeadline)
                    .foregroundStyle(.bifazInk)
                Text("capture.reading.onDevice")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            }
            .padding(BifazSpacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The capture choices, used by the "+" menu and by "Add receipt".
struct CaptureMenuItems: View {
    let choose: (CaptureSource) -> Void

    var body: some View {
        if DocumentScanner.isSupported {
            Button { choose(.scanner) } label: {
                Label { Text("capture.scan") } icon: { BifazIcon.scan.image }
            }
        }
        Button { choose(.photo) } label: {
            Label { Text("capture.photo") } icon: { BifazIcon.camera.image }
        }
        Button { choose(.pdf) } label: {
            Label { Text("capture.file") } icon: { BifazIcon.import.image }
        }
    }
}
