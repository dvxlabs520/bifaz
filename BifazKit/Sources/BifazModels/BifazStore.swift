import Foundation
import SwiftData
import os

// MARK: - Schema

/// Version 1 of the Bifaz schema (phases 0–2). Frozen: see `ModelsV1.swift`.
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

/// Version 2 (phase 3): adds `ExpenseVATLine`, one line per VAT rate of an expense.
public enum BifazSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Expense.self,
            ExpenseVATLine.self,
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

/// Version 3 (phase 4): exchange rate on the expense, recurrence day, archived
/// tags, recurring schedule, client and project in the merchant memory.
public enum BifazSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Expense.self,
            ExpenseVATLine.self,
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
    public static var schemas: [any VersionedSchema.Type] { [BifazSchemaV1.self, BifazSchemaV2.self, BifazSchemaV3.self] }
    public static var stages: [MigrationStage] { [v1ToV2, v2ToV3] }

    /// V2 → V3: only optional attributes, attributes with defaults and optional
    /// relationships are added. Afterwards, a rule's new `startDate` (which the
    /// store fills with the migration time) takes its `nextDate`: before v3 the
    /// next date was the only schedule a rule had.
    static let v2ToV3 = MigrationStage.custom(
        fromVersion: BifazSchemaV2.self,
        toVersion: BifazSchemaV3.self,
        willMigrate: nil,
        didMigrate: { context in
            for rule in try context.fetch(FetchDescriptor<BifazSchemaV3.RecurringRule>()) {
                rule.startDate = rule.nextDate
                rule.generatedThrough = nil
            }
            try context.save()
        }
    )

    /// V1 → V2. The store change is additive (a new entity and an optional
    /// relationship); after it, each expense with VAT gets its line from the
    /// v1 fields, which v2 keeps with the same meaning. See `VATMigration`.
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: BifazSchemaV1.self,
        toVersion: BifazSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            try VATMigration.createLines(in: context)
        }
    )
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
    public static var schema: Schema { Schema(versionedSchema: BifazSchemaV3.self) }

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
            return try makeContainer(at: storeURL())
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: BifazMigrationPlan.self,
            configurations: configuration
        )
    }

    /// Opens (and migrates, if needed) the store at `url`. The app uses the App
    /// Group URL; migration tests pass a temporary file.
    public static func makeContainer(at url: URL) throws -> ModelContainer {
        logger.info("Opening store at \(url.path(percentEncoded: false), privacy: .private)")
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: BifazMigrationPlan.self,
            configurations: configuration
        )
    }
}
