import Foundation

/// Receipt files (originals and thumbnails) on disk, outside the database.
///
/// Files get Data Protection `.complete`: readable only while the iPhone is
/// unlocked (PLAN §4 "Cifrado en reposo"). The database keeps only file names.
public struct ReceiptStore: Sendable {
    public let directory: URL

    /// `<App Group>/Library/Application Support/Bifaz/Receipts`
    public static func appGroup(fileManager: FileManager = .default) throws -> ReceiptStore {
        let database = try BifazStore.storeURL(fileManager: fileManager)
        return try ReceiptStore(
            directory: database.deletingLastPathComponent().appending(path: "Receipts", directoryHint: .isDirectory)
        )
    }

    /// Creates the folder if needed (tests pass a temporary folder).
    public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path(percentEncoded: false))
    }

    /// Writes a file and returns its generated name.
    public func save(_ data: Data, fileExtension: String) throws -> String {
        let name = "\(UUID().uuidString).\(fileExtension)"
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtection])
        return name
    }

    public func url(for fileName: String) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    public func data(for fileName: String) throws -> Data {
        try Data(contentsOf: url(for: fileName))
    }

    /// Removes a file; missing files are ignored.
    public func remove(_ fileName: String, fileManager: FileManager = .default) {
        guard !fileName.isEmpty else { return }
        try? fileManager.removeItem(at: url(for: fileName))
    }

    /// Deletes files no receipt refers to (left by a crash between writing the
    /// file and saving the expense). Returns how many were removed.
    @discardableResult
    public func removeOrphans(keeping names: Set<String>, fileManager: FileManager = .default) -> Int {
        let files = (try? fileManager.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
        let orphans = files.filter { !names.contains($0) }
        orphans.forEach { remove($0, fileManager: fileManager) }
        return orphans.count
    }
}

/// A receipt whose files are already in the `ReceiptStore`, ready to attach.
public struct StoredReceiptFiles: Sendable, Equatable {
    public let fileName: String
    public let thumbnailFileName: String
    public let typeIdentifier: String
    public let recognizedText: String?

    public init(fileName: String, thumbnailFileName: String, typeIdentifier: String, recognizedText: String?) {
        self.fileName = fileName
        self.thumbnailFileName = thumbnailFileName
        self.typeIdentifier = typeIdentifier
        self.recognizedText = recognizedText
    }

    /// Writes the original and its thumbnail; cleans up if the second write fails.
    public static func store(
        fileData: Data,
        fileExtension: String,
        typeIdentifier: String,
        thumbnailData: Data?,
        recognizedText: String?,
        in store: ReceiptStore
    ) throws -> StoredReceiptFiles {
        let fileName = try store.save(fileData, fileExtension: fileExtension)
        do {
            let thumbnail = try thumbnailData.map { try store.save($0, fileExtension: "jpg") } ?? ""
            return StoredReceiptFiles(
                fileName: fileName, thumbnailFileName: thumbnail,
                typeIdentifier: typeIdentifier, recognizedText: recognizedText
            )
        } catch {
            store.remove(fileName)
            throw error
        }
    }
}
