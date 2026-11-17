import Foundation
import SwiftData
import os

// MARK: - Schema

/// Version 1 of the Bifaz schema. Future versions add a new `VersionedSchema`
/// and a stage to `BifazMigrationPlan`.
public enum BifazSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Expense.self,
            Receipt.self,
            ExpenseCategory.self,
            Tag.self,
            Budget.self,
            RecurringRule.self,
            ExpenseSession.self,
            MerchantRule.self,
        ]
    }
}

public enum BifazMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [BifazSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

// MARK: - Store

/// Builds the app's `ModelContainer`.
///
/// The on-disk store lives in the App Group container so the app, the share
/// extension and the widgets read the same data. CloudKit is explicitly off;
/// the model is ready for it (see `Models.swift`).
public enum BifazStore {
    public static let appGroupIdentifier = "group.com.dvxlabs.bifaz"
    public static let storeFileName = "Bifaz.store"

    public enum StoreError: Error, Equatable {
        /// The App Group entitlement is missing, so iOS gives no shared container.
        case appGroupUnavailable(String)
    }

    private static let logger = Logger(subsystem: "com.dvxlabs.bifaz", category: "store")

    /// `<App Group>/Library/Application Support/Bifaz/Bifaz.store`
    public static func storeURL(fileManager: FileManager = .default) throws -> URL {
        guard let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw StoreError.appGroupUnavailable(appGroupIdentifier)
        }
        let directory = group
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Application Support", directoryHint: .isDirectory)
            .appending(path: "Bifaz", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        // The database must stay readable after the first unlock since boot, so
        // Apple Pay payments can be recorded in the background (phase 7). New
        // files in this folder inherit the class. Receipts use `.complete`.
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path(percentEncoded: false)
        )
        return directory.appending(path: storeFileName, directoryHint: .notDirectory)
    }

    /// The schema of the current version.
    public static var schema: Schema { Schema(versionedSchema: BifazSchemaV1.self) }

    /// Creates the container. Pass `inMemory: true` for tests and previews.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        } else {
            let url = try storeURL()
            logger.info("Opening store at \(url.path(percentEncoded: false), privacy: .private)")
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: BifazMigrationPlan.self,
            configurations: configuration
        )
    }
}
