import Foundation
import SwiftData

// Bifaz data model, schema version 1.
//
// CloudKit compatibility rules, applied from day one even though sync is off:
// - every stored property has a default value or is optional;
// - every relationship is optional and has an inverse;
// - no `.unique` attributes and no `.deny` delete rules.
// Money is always `Decimal`. Enums are stored as raw strings.

// MARK: - Expense (Gasto)

@Model
public final class Expense {
    /// Stable identifier for backups and matching. Not unique-constrained (CloudKit).
    public var id: UUID = UUID()
    /// Amount in the original currency, taxes included (TTC).
    public var amount: Decimal = 0
    /// ISO 4217 code of `amount`.
    public var currencyCode: String = "EUR"
    /// Equivalent in euros. Equal to `amount` when `currencyCode` is EUR.
    public var amountInEUR: Decimal = 0
    public var date: Date = Date.now
    public var merchant: String = ""
    public var spaceRawValue: String = Space.personal.rawValue
    /// VAT rate as a fraction (0.20 for 20 %). `nil` when unknown or not applicable.
    public var vatRate: Decimal?
    /// VAT amount in the original currency.
    public var vatAmount: Decimal?
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
    /// Original file (image or PDF), kept outside the database file.
    @Attribute(.externalStorage)
    public var fileData: Data?
    /// Uniform Type Identifier of `fileData`, e.g. `public.jpeg` or `com.adobe.pdf`.
    public var fileTypeIdentifier: String = "public.jpeg"
    /// Small preview, stored apart from the original so lists never load the full file.
    @Attribute(.externalStorage)
    public var thumbnailData: Data?
    /// Text read from the document, if any.
    public var recognizedText: String?
    public var createdAt: Date = Date.now

    public var expense: Expense?

    public init(
        fileData: Data? = nil,
        fileTypeIdentifier: String = "public.jpeg",
        thumbnailData: Data? = nil,
        recognizedText: String? = nil
    ) {
        self.fileData = fileData
        self.fileTypeIdentifier = fileTypeIdentifier
        self.thumbnailData = thumbnailData
        self.recognizedText = recognizedText
    }
}

// MARK: - Category (Categoría)

/// Named `ExpenseCategory` to avoid the Objective-C runtime's `Category` type.
@Model
public final class ExpenseCategory {
    public var id: UUID = UUID()
    public var name: String = ""
    /// SF Symbol name.
    public var symbolName: String = "tag"
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
        symbolName: String = "tag",
        colorKey: String = "",
        space: Space,
        sortOrder: Int = 0
    ) {
        self.name = name
        self.symbolName = symbolName
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
