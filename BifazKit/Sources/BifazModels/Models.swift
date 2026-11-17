import Foundation
import SwiftData

// Bifaz data model, schema version 1.
//
// CloudKit compatibility rules, applied from day one even though sync is off:
// - every stored property has a default value or is optional;
// - every relationship is optional and has an inverse;
// - no `.unique` attributes and no `.deny` delete rules.
// Money is always `Decimal`. Enums are stored as raw strings.
//
// The model classes are nested in `BifazSchemaV1` so this version stays frozen
// once real data exists: a future V2 copies them into `BifazSchemaV2` and the
// migration plan maps one to the other. Top-level typealiases (below) point at
// the current version, so the rest of the code never names the schema.
//
// Sensitive fields carry `.allowsCloudEncryption` so that, when iCloud sync is
// switched on (phase 6), CloudKit stores them encrypted from the first deployment.

extension BifazSchemaV1 {
    // MARK: - Expense (Gasto)

    @Model
    public final class Expense {
        // History and Summary filter by date and space and sort by date.
        #Index<Expense>([\.date], [\.spaceRawValue, \.date], [\.statusRawValue])

        /// Stable identifier for backups and matching. Not unique-constrained (CloudKit).
        public var id: UUID = UUID()
        /// Amount in the original currency, taxes included (TTC).
        /// Written only through `ExpenseService`, which keeps `amountInEUR` and VAT in sync.
        @Attribute(.allowsCloudEncryption)
        public internal(set) var amount: Decimal = 0
        /// ISO 4217 code of `amount`.
        public var currencyCode: String = "EUR"
        /// Equivalent in euros. Equal to `amount` when `currencyCode` is EUR.
        @Attribute(.allowsCloudEncryption)
        public internal(set) var amountInEUR: Decimal = 0
        public var date: Date = Date.now
        @Attribute(.allowsCloudEncryption)
        public var merchant: String = ""
        public var spaceRawValue: String = Space.personal.rawValue
        /// VAT rate as a fraction (0.20 for 20 %). `nil` when unknown or not applicable.
        public internal(set) var vatRate: Decimal?
        /// VAT amount in the original currency.
        @Attribute(.allowsCloudEncryption)
        public internal(set) var vatAmount: Decimal?
        @Attribute(.allowsCloudEncryption)
        public var note: String = ""
        public var sourceRawValue: String = ExpenseSource.manual.rawValue
        public var statusRawValue: String = ExpenseStatus.confirmed.rawValue
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        @Relationship(deleteRule: .nullify, inverse: \ExpenseCategory.expenses)
        public var category: ExpenseCategory?

        @Relationship(deleteRule: .nullify, inverse: \Tag.expenses)
        public var tags: [Tag]? = []

        /// Deleting an expense deletes its receipt.
        @Relationship(deleteRule: .cascade, inverse: \Receipt.expense)
        public var receipt: Receipt?

        @Relationship(deleteRule: .nullify, inverse: \ExpenseSession.expenses)
        public var session: ExpenseSession?

        /// The recurring rule that generated this expense, if any.
        @Relationship(deleteRule: .nullify, inverse: \RecurringRule.generatedExpenses)
        public var recurringRule: RecurringRule?

        public init(
            amount: Decimal,
            currencyCode: String = "EUR",
            amountInEUR: Decimal? = nil,
            date: Date = .now,
            merchant: String = "",
            space: Space,
            category: ExpenseCategory? = nil,
            vatRate: Decimal? = nil,
            vatAmount: Decimal? = nil,
            note: String = "",
            source: ExpenseSource = .manual,
            status: ExpenseStatus = .confirmed
        ) {
            self.amount = amount
            self.currencyCode = currencyCode
            self.amountInEUR = amountInEUR ?? amount
            self.date = date
            self.merchant = merchant
            self.spaceRawValue = space.rawValue
            self.category = category
            self.vatRate = vatRate
            self.vatAmount = vatAmount
            self.note = note
            self.sourceRawValue = source.rawValue
            self.statusRawValue = status.rawValue
        }

        public var space: Space {
            get { Space(rawValue: spaceRawValue) ?? .personal }
            set { spaceRawValue = newValue.rawValue }
        }

        public var source: ExpenseSource {
            get { ExpenseSource(rawValue: sourceRawValue) ?? .manual }
            set { sourceRawValue = newValue.rawValue }
        }

        public var status: ExpenseStatus {
            get { ExpenseStatus(rawValue: statusRawValue) ?? .confirmed }
            set { statusRawValue = newValue.rawValue }
        }
    }

    // MARK: - Receipt (Justificante)

    @Model
    public final class Receipt {
        public var id: UUID = UUID()
        /// File name of the original (image or PDF) in the receipts folder.
        /// Receipts live outside the database so they can get the strictest Data
        /// Protection class (readable only while the iPhone is unlocked) and be
        /// encrypted before any upload. Written in phase 2.
        public var fileName: String = ""
        /// Uniform Type Identifier of the original, e.g. `public.jpeg` or `com.adobe.pdf`.
        public var fileTypeIdentifier: String = "public.jpeg"
        /// File name of the small preview in the receipts folder (same protection).
        public var thumbnailFileName: String = ""
        /// Text read from the document, if any (kept in the database for search).
        @Attribute(.allowsCloudEncryption)
        public var recognizedText: String?
        public var createdAt: Date = Date.now

        public var expense: Expense?

        public init(
            fileName: String = "",
            fileTypeIdentifier: String = "public.jpeg",
            thumbnailFileName: String = "",
            recognizedText: String? = nil
        ) {
            self.fileName = fileName
            self.fileTypeIdentifier = fileTypeIdentifier
            self.thumbnailFileName = thumbnailFileName
            self.recognizedText = recognizedText
        }
    }

    // MARK: - Category (Categoría)

    /// Named `ExpenseCategory` to avoid the Objective-C runtime's `Category` type.
    @Model
    public final class ExpenseCategory {
        public var id: UUID = UUID()
        public var name: String = ""
        /// Name of a `BifazIcon` (BifazDesign). Stored as text so the model stays UI-free.
        public var iconName: String = "other"
        /// Identifier of the default category this one was seeded from (empty for user-created ones).
        /// Lets seeding stay idempotent and lets the app recognise built-in categories.
        public var seedKey: String = ""
        /// Key into the category palette (defined in phase 3), not a raw colour.
        public var colorKey: String = ""
        public var spaceRawValue: String = Space.personal.rawValue
        public var sortOrder: Int = 0
        public var createdAt: Date = Date.now

        public var expenses: [Expense]? = []

        @Relationship(deleteRule: .cascade, inverse: \Budget.category)
        public var budgets: [Budget]? = []

        @Relationship(deleteRule: .nullify, inverse: \RecurringRule.category)
        public var recurringRules: [RecurringRule]? = []

        @Relationship(deleteRule: .nullify, inverse: \MerchantRule.category)
        public var merchantRules: [MerchantRule]? = []

        public init(
            name: String,
            iconName: String = "other",
            colorKey: String = "",
            space: Space,
            sortOrder: Int = 0,
            seedKey: String = ""
        ) {
            self.name = name
            self.iconName = iconName
            self.seedKey = seedKey
            self.colorKey = colorKey
            self.spaceRawValue = space.rawValue
            self.sortOrder = sortOrder
        }

        public var space: Space {
            get { Space(rawValue: spaceRawValue) ?? .personal }
            set { spaceRawValue = newValue.rawValue }
        }
    }

    // MARK: - Tag (Etiqueta)

    @Model
    public final class Tag {
        public var id: UUID = UUID()
        public var name: String = ""
        public var kindRawValue: String = TagKind.client.rawValue
        public var createdAt: Date = Date.now

        public var expenses: [Expense]? = []

        @Relationship(deleteRule: .nullify, inverse: \ExpenseSession.tag)
        public var sessions: [ExpenseSession]? = []

        @Relationship(deleteRule: .nullify, inverse: \RecurringRule.tags)
        public var recurringRules: [RecurringRule]? = []

        public init(name: String, kind: TagKind) {
            self.name = name
            self.kindRawValue = kind.rawValue
        }

        public var kind: TagKind {
            get { TagKind(rawValue: kindRawValue) ?? .client }
            set { kindRawValue = newValue.rawValue }
        }
    }

    // MARK: - Budget (Presupuesto)

    @Model
    public final class Budget {
        public var id: UUID = UUID()
        /// Monthly limit in EUR.
        public var monthlyAmount: Decimal = 0
        public var createdAt: Date = Date.now

        public var category: ExpenseCategory?

        public init(category: ExpenseCategory?, monthlyAmount: Decimal) {
            self.category = category
            self.monthlyAmount = monthlyAmount
        }
    }

    // MARK: - Recurring rule (Regla recurrente)

    /// Generates an expense from its template on `nextDate`, then advances `nextDate`.
    @Model
    public final class RecurringRule {
        public var id: UUID = UUID()

        // Expense template.
        public var amount: Decimal = 0
        public var currencyCode: String = "EUR"
        public var merchant: String = ""
        public var spaceRawValue: String = Space.personal.rawValue
        public var vatRate: Decimal?
        public var note: String = ""

        // Schedule.
        public var frequencyRawValue: String = RecurrenceFrequency.monthly.rawValue
        public var nextDate: Date = Date.now
        public var isActive: Bool = true
        public var createdAt: Date = Date.now

        public var category: ExpenseCategory?
        public var tags: [Tag]? = []
        public var generatedExpenses: [Expense]? = []

        public init(
            amount: Decimal,
            currencyCode: String = "EUR",
            merchant: String = "",
            space: Space,
            category: ExpenseCategory? = nil,
            vatRate: Decimal? = nil,
            note: String = "",
            frequency: RecurrenceFrequency,
            nextDate: Date
        ) {
            self.amount = amount
            self.currencyCode = currencyCode
            self.merchant = merchant
            self.spaceRawValue = space.rawValue
            self.category = category
            self.vatRate = vatRate
            self.note = note
            self.frequencyRawValue = frequency.rawValue
            self.nextDate = nextDate
        }

        public var space: Space {
            get { Space(rawValue: spaceRawValue) ?? .personal }
            set { spaceRawValue = newValue.rawValue }
        }

        public var frequency: RecurrenceFrequency {
            get { RecurrenceFrequency(rawValue: frequencyRawValue) ?? .monthly }
            set { frequencyRawValue = newValue.rawValue }
        }
    }

    // MARK: - Expense session (Sesión de gastos)

    /// Named `ExpenseSession` to avoid confusion with network or auth sessions.
    @Model
    public final class ExpenseSession {
        public var id: UUID = UUID()
        public var name: String = ""
        public var spaceRawValue: String = Space.pro.rawValue
        public var startedAt: Date = Date.now
        /// `nil` while the session is running.
        public var endedAt: Date?

        public var tag: Tag?
        public var expenses: [Expense]? = []

        public init(name: String, space: Space, tag: Tag? = nil, startedAt: Date = .now) {
            self.name = name
            self.spaceRawValue = space.rawValue
            self.tag = tag
            self.startedAt = startedAt
        }

        public var space: Space {
            get { Space(rawValue: spaceRawValue) ?? .pro }
            set { spaceRawValue = newValue.rawValue }
        }

        public var isActive: Bool { endedAt == nil }
    }

    // MARK: - Merchant rule (Regla de comercio)

    /// What Bifaz learned about a merchant: the space and category used last time.
    @Model
    public final class MerchantRule {
        public var id: UUID = UUID()
        /// Normalised merchant name used for matching (see `MerchantRule.key(for:)`).
        public var merchantKey: String = ""
        /// Merchant name as last shown to the user.
        public var merchantName: String = ""
        public var spaceRawValue: String = Space.personal.rawValue
        public var updatedAt: Date = Date.now

        public var category: ExpenseCategory?

        public init(merchantName: String, space: Space, category: ExpenseCategory? = nil) {
            self.merchantKey = Self.key(for: merchantName)
            self.merchantName = merchantName
            self.spaceRawValue = space.rawValue
            self.category = category
        }

        public var space: Space {
            get { Space(rawValue: spaceRawValue) ?? .personal }
            set { spaceRawValue = newValue.rawValue }
        }

        /// Case-, accent- and whitespace-insensitive key for a merchant name.
        public static func key(for merchantName: String) -> String {
            merchantName
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
        }
    }
}

// MARK: - Current version

public typealias Expense = BifazSchemaV1.Expense
public typealias Receipt = BifazSchemaV1.Receipt
public typealias ExpenseCategory = BifazSchemaV1.ExpenseCategory
public typealias Tag = BifazSchemaV1.Tag
public typealias Budget = BifazSchemaV1.Budget
public typealias RecurringRule = BifazSchemaV1.RecurringRule
public typealias ExpenseSession = BifazSchemaV1.ExpenseSession
public typealias MerchantRule = BifazSchemaV1.MerchantRule
