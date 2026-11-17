import SwiftUI
import SwiftData
import QuickLook
import BifazModels
import BifazReading
import BifazDesign

/// The receipt of an expense in its detail: thumbnail and original when
/// attached, or a prompt to add one.
struct ReceiptSection: View {
    let expense: Expense

    @Environment(\.modelContext) private var modelContext
    @Environment(\.receiptStore) private var receiptStore
    @State private var source: CaptureSource?
    @State private var previewURL: URL?
    @State private var confirmingRemoval = false
    @State private var failed = false
    @State private var feedback = 0

    var body: some View {
        Group {
            if let receipt = expense.receipt {
                attachedCard(receipt)
            } else {
                emptyCard
            }
        }
        .receiptCapture(source: $source) { captured in attach(captured) }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { old, new in
            // The viewer closed: delete the temporary copy.
            if new == nil, let old { ReceiptPreviewCopy.remove(old) }
        }
        .sensoryFeedback(.success, trigger: feedback)
        .confirmationDialog(
            Text("receipt.remove.title", tableName: "History"),
            isPresented: $confirmingRemoval,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                removeReceipt()
            } label: {
                Text("receipt.remove.confirm", tableName: "History")
            }
            Button(role: .cancel) {} label: {
                Text("history.delete.cancel", tableName: "History")
            }
        } message: {
            Text("receipt.remove.message", tableName: "History")
        }
        .alert(Text("receipt.error.title", tableName: "History"), isPresented: $failed) {
            Button(role: .cancel) {} label: {
                Text("receipt.error.ok", tableName: "History")
            }
        } message: {
            Text("receipt.error.message", tableName: "History")
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous)
    }

    // MARK: With a receipt

    private func attachedCard(_ receipt: Receipt) -> some View {
        let isPDF = receipt.fileTypeIdentifier == "com.adobe.pdf"
        let kind = isPDF
            ? String(localized: "receipt.kind.pdf", table: "History")
            : String(localized: "receipt.kind.photo", table: "History")
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: BifazSpacing.s) {
                Button {
                    previewURL = ReceiptPreviewCopy.make(of: receipt, for: expense, in: receiptStore)
                } label: {
                    HStack(spacing: BifazSpacing.m) {
                        ReceiptThumbnailLoader(fileName: receipt.thumbnailFileName, side: 56)
                        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
                            Text("receipt.title", tableName: "History")
                                .font(.bifazHeadline)
                                .foregroundStyle(Color.bifazInk)
                            Text(verbatim: kind)
                                .font(.bifazCaption)
                                .foregroundStyle(Color.bifazInkSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(receiptStore == nil)
                .accessibilityLabel(Text("receipt.a11y \(kind)", tableName: "History"))

                Menu {
                    Menu {
                        CaptureMenuItems { source = $0 }
                    } label: {
                        Label { Text("receipt.replace", tableName: "History") } icon: { BifazIcon.edit.image }
                    }
                    Button(role: .destructive) {
                        confirmingRemoval = true
                    } label: {
                        Label { Text("receipt.remove", tableName: "History") } icon: { BifazIcon.trash.image }
                    }
                } label: {
                    BifazIconView(.edit, size: 20)
                        .foregroundStyle(Color.bifazInk)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("receipt.manage", tableName: "History"))
            }
            .padding(BifazSpacing.s)

            if let text = receipt.recognizedText, !text.isEmpty {
                HairlineDivider()
                DisclosureGroup {
                    Text(verbatim: text)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.bifazInkSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, BifazSpacing.xs)
                } label: {
                    Text("receipt.text.title", tableName: "History")
                        .font(.bifazBody)
                        .foregroundStyle(Color.bifazInk)
                }
                .tint(Color.bifazInkSecondary)
                .padding(BifazSpacing.m)
            }
        }
        .overlay(shape.strokeBorder(Color.bifazHairline, lineWidth: 1))
        .padding(.bottom, BifazSpacing.xl)
    }

    // MARK: Without a receipt

    private var isMissing: Bool { expense.space == .pro }

    private var emptyCard: some View {
        VStack(spacing: BifazSpacing.m) {
            HStack(spacing: BifazSpacing.m) {
                BifazIconView(.receiptPending, size: 28)
                    .foregroundStyle(isMissing ? Color.bifazWarning : Color.bifazInkSecondary)
                Group {
                    if isMissing {
                        Text("receipt.empty.titlePro", tableName: "History")
                            .foregroundStyle(Color.bifazWarning)
                    } else {
                        Text("receipt.empty.title", tableName: "History")
                            .foregroundStyle(Color.bifazInk)
                    }
                }
                .font(.bifazHeadline)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            Menu {
                CaptureMenuItems { source = $0 }
            } label: {
                Text("receipt.add", tableName: "History")
            }
            .buttonStyle(.bifazSecondary)
        }
        .padding(BifazSpacing.m)
        .background(isMissing ? Color.bifazWarningTint : .clear, in: shape)
        .overlay(
            shape.strokeBorder(
                isMissing ? Color.bifazWarning.opacity(0.5) : Color.bifazHairline,
                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
            )
        )
        .padding(.bottom, BifazSpacing.xl)
    }

    // MARK: Actions

    private func attach(_ captured: CapturedReceipt) {
        guard let store = receiptStore else { failed = true; return }
        var files: StoredReceiptFiles?
        do {
            let stored = try StoredReceiptFiles.store(
                fileData: captured.fileData,
                fileExtension: captured.fileExtension,
                typeIdentifier: captured.typeIdentifier,
                thumbnailData: captured.thumbnailData,
                recognizedText: captured.reading.recognizedText,
                in: store
            )
            files = stored
            try ExpenseService.attachReceipt(stored, to: expense, in: modelContext, store: store)
            feedback += 1
        } catch {
            if let files {
                store.remove(files.fileName)
                store.remove(files.thumbnailFileName)
            }
            modelContext.rollback()
            failed = true
        }
    }

    private func removeReceipt() {
        guard let receipt = expense.receipt else { return }
        let names = [receipt.fileName, receipt.thumbnailFileName]
        do {
            modelContext.delete(receipt)
            if expense.space == .pro { expense.status = .receiptPending }
            expense.updatedAt = .now
            try modelContext.save()
            names.forEach { receiptStore?.remove($0) }
        } catch {
            modelContext.rollback()
            failed = true
        }
    }
}

/// Loads a receipt thumbnail from the store off the main thread.
private struct ReceiptThumbnailLoader: View {
    let fileName: String
    let side: CGFloat

    @Environment(\.receiptStore) private var receiptStore
    @State private var image: UIImage?

    var body: some View {
        ReceiptThumbnail(image: image.map { Image(uiImage: $0) }, state: .attached, side: side)
            .task(id: fileName) {
                guard let store = receiptStore, !fileName.isEmpty else { return }
                let name = fileName
                image = await Task.detached(priority: .userInitiated) {
                    UIImage(contentsOfFile: store.url(for: name).path(percentEncoded: false))
                }.value
            }
    }
}

#if DEBUG
private struct ReceiptSectionPreview: View {
    let container = HistoryPreviewData.container()

    var body: some View {
        Host().modelContainer(container)
    }

    private struct Host: View {
        @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

        var body: some View {
            ScrollView {
                VStack {
                    if let pro = expenses.first(where: { $0.merchant == "SNCF" }) { ReceiptSection(expense: pro) }
                    if let personal = expenses.first(where: { $0.merchant == "Monoprix" }) { ReceiptSection(expense: personal) }
                }
                .padding()
            }
            .background(Color.bifazPaper)
        }
    }
}

#Preview("Light") { ReceiptSectionPreview() }
#Preview("Dark") { ReceiptSectionPreview().preferredColorScheme(.dark) }
#Preview("Large text") { ReceiptSectionPreview().dynamicTypeSize(.accessibility3) }
#endif

/// Quick Look works on a temporary copy of the receipt, never on the original:
/// the title is readable ("SNCF – 21 oct. 2026.pdf" instead of a UUID) and a
/// Markup edit in the viewer can't alter the stored receipt. The copy keeps the
/// `.complete` protection and is deleted when the viewer closes.
enum ReceiptPreviewCopy {
    static func make(of receipt: Receipt, for expense: Expense, in store: ReceiptStore?) -> URL? {
        guard let store, let data = try? store.data(for: receipt.fileName) else { return nil }
        let folder = FileManager.default.temporaryDirectory.appending(path: "ReceiptPreview", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = (receipt.fileName as NSString).pathExtension
        let title = "\(expense.displayTitle) – \(expense.date.formatted(date: .abbreviated, time: .omitted))"
        let safeTitle = title.replacing(/[\/:*?"<>|]/, with: "-")
        let url = folder.appending(path: "\(safeTitle).\(ext)", directoryHint: .notDirectory)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
        }
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
