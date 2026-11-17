import Foundation
import SwiftData
import Testing
@testable import BifazModels

/// A receipts folder in the temporary directory, removed when `cleanUp()` runs.
private struct TemporaryStore {
    let root: URL
    let store: ReceiptStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "BifazReceiptTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = try ReceiptStore(directory: root.appending(path: "Receipts", directoryHint: .isDirectory))
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: store.url(for: name).path(percentEncoded: false))
    }

    var fileNames: [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: store.directory.path(percentEncoded: false))) ?? []
    }
}

@Suite("ReceiptStore")
struct ReceiptStoreTests {
    @Test("save returns a unique name with the extension and the data round-trips")
    func saveAndRead() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let data = Data("receipt".utf8)

        let first = try temp.store.save(data, fileExtension: "jpg")
        let second = try temp.store.save(data, fileExtension: "jpg")

        #expect(first.hasSuffix(".jpg"))
        #expect(first != second)
        #expect(try temp.store.data(for: first) == data)
        #expect(temp.exists(first) && temp.exists(second))
    }

    @Test("remove deletes the file and ignores missing or empty names")
    func remove() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let name = try temp.store.save(Data([1, 2, 3]), fileExtension: "pdf")

        temp.store.remove(name)
        #expect(!temp.exists(name))
        temp.store.remove(name)
        temp.store.remove("does-not-exist.jpg")
        temp.store.remove("")
        #expect(temp.fileNames.isEmpty)
    }

    @Test("removeOrphans removes only unknown files")
    func orphans() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let kept = try temp.store.save(Data([1]), fileExtension: "jpg")
        let keptThumbnail = try temp.store.save(Data([2]), fileExtension: "jpg")
        let orphanA = try temp.store.save(Data([3]), fileExtension: "jpg")
        let orphanB = try temp.store.save(Data([4]), fileExtension: "pdf")

        let removed = temp.store.removeOrphans(keeping: [kept, keptThumbnail])

        #expect(removed == 2)
        #expect(temp.exists(kept) && temp.exists(keptThumbnail))
        #expect(!temp.exists(orphanA) && !temp.exists(orphanB))
    }

    @Test("StoredReceiptFiles.store writes the original and its thumbnail")
    func storeFiles() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let files = try StoredReceiptFiles.store(
            fileData: Data("original".utf8), fileExtension: "pdf", typeIdentifier: "com.adobe.pdf",
            thumbnailData: Data("thumb".utf8), recognizedText: "TOTAL 1,00", in: temp.store
        )

        #expect(files.fileName.hasSuffix(".pdf"))
        #expect(files.thumbnailFileName.hasSuffix(".jpg"))
        #expect(files.typeIdentifier == "com.adobe.pdf")
        #expect(files.recognizedText == "TOTAL 1,00")
        #expect(try temp.store.data(for: files.fileName) == Data("original".utf8))
        #expect(try temp.store.data(for: files.thumbnailFileName) == Data("thumb".utf8))
    }

    @Test("StoredReceiptFiles.store without a thumbnail leaves its name empty")
    func storeWithoutThumbnail() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let files = try StoredReceiptFiles.store(
            fileData: Data([1]), fileExtension: "jpg", typeIdentifier: "public.jpeg",
            thumbnailData: nil, recognizedText: nil, in: temp.store
        )
        #expect(files.thumbnailFileName.isEmpty)
        #expect(temp.fileNames == [files.fileName])
    }
}

@MainActor
@Suite("Expenses with receipts")
struct ExpenseReceiptTests {
    private func stored(_ temp: TemporaryStore, text: String? = nil) throws -> StoredReceiptFiles {
        try StoredReceiptFiles.store(
            fileData: Data("original".utf8), fileExtension: "jpg", typeIdentifier: "public.jpeg",
            thumbnailData: Data("thumb".utf8), recognizedText: text, in: temp.store
        )
    }

    @Test("create(from:receipt:) attaches the receipt and confirms the expense")
    func createWithReceipt() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let files = try stored(temp, text: "TOTAL TTC 12,00")

        let expense = try ExpenseService.create(
            from: ExpenseDraft(amount: 12, merchant: "Monoprix", space: .pro), receipt: files, in: context
        )

        let receipt = try #require(expense.receipt)
        #expect(receipt.fileName == files.fileName)
        #expect(receipt.thumbnailFileName == files.thumbnailFileName)
        #expect(receipt.recognizedText == "TOTAL TTC 12,00")
        #expect(expense.status == .confirmed)
        #expect(try context.fetch(FetchDescriptor<Receipt>()).count == 1)
    }

    @Test("attachReceipt on a receiptPending expense confirms it and deletes the previous files")
    func attachReplaces() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let old = try stored(temp)
        let expense = try ExpenseService.create(from: ExpenseDraft(amount: 20, space: .pro), receipt: old, in: context)
        expense.status = .receiptPending
        let new = try stored(temp, text: "new")

        try ExpenseService.attachReceipt(new, to: expense, in: context, store: temp.store)

        #expect(expense.status == .confirmed)
        #expect(expense.receipt?.fileName == new.fileName)
        #expect(!temp.exists(old.fileName) && !temp.exists(old.thumbnailFileName))
        #expect(temp.exists(new.fileName) && temp.exists(new.thumbnailFileName))
        #expect(try context.fetch(FetchDescriptor<Receipt>()).count == 1)
    }

    @Test("attachReceipt on an expense without receipt confirms it and keeps the new files")
    func attachFirst() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let expense = try ExpenseService.create(from: ExpenseDraft(amount: 20, space: .pro), in: context)
        expense.status = .receiptPending
        let files = try stored(temp)

        try ExpenseService.attachReceipt(files, to: expense, in: context, store: temp.store)

        #expect(expense.status == .confirmed)
        #expect(expense.receipt?.fileName == files.fileName)
        #expect(temp.exists(files.fileName))
    }

    @Test("delete removes the receipt files and the receipt record")
    func deleteRemovesFiles() throws {
        let temp = try TemporaryStore()
        defer { temp.cleanUp() }
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let files = try stored(temp)
        let expense = try ExpenseService.create(from: ExpenseDraft(amount: 5), receipt: files, in: context)
        #expect(temp.exists(files.fileName))

        try ExpenseService.delete(expense, in: context, store: temp.store)

        #expect(!temp.exists(files.fileName) && !temp.exists(files.thumbnailFileName))
        #expect(try context.fetch(FetchDescriptor<Expense>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Receipt>()).isEmpty)
    }
}
