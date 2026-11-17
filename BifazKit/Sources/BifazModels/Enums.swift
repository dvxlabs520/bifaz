import Foundation

// Value types shared by the model and the interface.
//
// Models store these as raw `String` values (`…RawValue` properties) so that
// predicates can filter on them and the schema stays CloudKit-compatible.
// Raw values are persisted: never rename them without a migration.

/// One of the two "faces" of Bifaz.
public enum Space: String, CaseIterable, Codable, Sendable, Identifiable {
    case pro
    case personal

    public var id: String { rawValue }
}

/// The global space selector: one space or both.
public enum SpaceFilter: String, CaseIterable, Codable, Sendable, Identifiable {
    case pro
    case personal
    case all

    public var id: String { rawValue }

    /// The single space this filter selects, or `nil` for `.all`.
    public var space: Space? {
        switch self {
        case .pro: .pro
        case .personal: .personal
        case .all: nil
        }
    }

    /// Whether an item that belongs to `space` passes this filter.
    public func includes(_ space: Space) -> Bool {
        self == .all || self.space == space
    }
}

/// How an expense entered Bifaz.
public enum ExpenseSource: String, CaseIterable, Codable, Sendable {
    case manual
    case scanner
    case applePay
    case recurring
}

/// Review state of an expense.
public enum ExpenseStatus: String, CaseIterable, Codable, Sendable {
    /// Checked by the user.
    case confirmed
    /// Arrived incomplete (e.g. Apple Pay with no amount) and waits in the review inbox.
    case needsReview
    /// Professional expense with no receipt attached yet.
    case receiptPending
}

/// Kind of a professional tag.
public enum TagKind: String, CaseIterable, Codable, Sendable {
    case client
    case project
}

/// How often a recurring rule generates an expense.
public enum RecurrenceFrequency: String, CaseIterable, Codable, Sendable {
    case weekly
    case monthly
    case quarterly
    case yearly
}

/// How sure the reader is about a value it extracted from a receipt.
/// Produced by `BifazReading` (phase 2), shown by the confirmation field.
public enum ReadingConfidence: String, CaseIterable, Codable, Sendable {
    case high
    case medium
    case low
}
