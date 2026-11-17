import SwiftUI
import SwiftData
import BifazModels

/// Opens the database off the main thread at launch, seeds the default
/// categories, and exposes a retryable state to the UI.
@Observable
final class StoreLoader {
    enum State {
        case loading
        case ready(ModelContainer, ReceiptStore?)
        /// Error domain and code, safe to show and to quote to support.
        case failed(code: String)
    }

    private(set) var state: State = .loading

    func load() async {
        state = .loading
        do {
            let inMemory = Self.isUITesting
            let container = try await Task.detached(priority: .userInitiated) {
                try BifazStore.makeContainer(inMemory: inMemory)
            }.value
            try CategorySeeder.seedIfNeeded(in: container.mainContext)
            try CategorySeeder.adoptTranslatedDefaults(in: container.mainContext, knownNames: CategoryNames.allTranslations)
            #if DEBUG
            try insertSampleDataIfRequested(into: container.mainContext)
            #endif
            // UI tests run on an empty in-memory store: give them their own folder,
            // otherwise the orphan sweep would delete the real receipts.
            let receipts = inMemory
                ? try? ReceiptStore(directory: FileManager.default.temporaryDirectory.appending(path: "BifazUITestReceipts"))
                : try? ReceiptStore.appGroup()
            if let receipts, !inMemory { removeOrphanReceiptFiles(store: receipts, context: container.mainContext) }
            state = .ready(container, receipts)
        } catch {
            let nsError = error as NSError
            Log.app.error("""
                Store failed to open: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public) \
                \(String(describing: error), privacy: .private)
                """)
            state = .failed(code: "\(nsError.domain) \(nsError.code)")
        }
    }

    /// `-BifazUITesting YES` (Debug only): a fresh in-memory store for UI tests.
    private static var isUITesting: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "BifazUITesting")
        #else
        false
        #endif
    }

    /// Files written for a receipt whose expense was never saved (crash, force quit).
    private func removeOrphanReceiptFiles(store: ReceiptStore, context: ModelContext) {
        guard let receipts = try? context.fetch(FetchDescriptor<Receipt>()) else { return }
        let names = Set(receipts.flatMap { [$0.fileName, $0.thumbnailFileName] })
        let removed = store.removeOrphans(keeping: names)
        if removed > 0 { Log.app.notice("Removed \(removed, privacy: .public) orphan receipt files") }
    }

    #if DEBUG
    /// `-BifazSampleData YES` fills an empty store with sample expenses (screenshots, manual QA).
    private func insertSampleDataIfRequested(into context: ModelContext) throws {
        guard UserDefaults.standard.bool(forKey: "BifazSampleData"),
              try context.fetchCount(FetchDescriptor<Expense>()) == 0 else { return }
        try SampleData.insert(into: context)
    }
    #endif
}

/// Settings shared with the future widgets and share extension (App Group).
enum AppDefaults {
    static let shared: UserDefaults = UserDefaults(suiteName: BifazStore.appGroupIdentifier) ?? .standard
}
