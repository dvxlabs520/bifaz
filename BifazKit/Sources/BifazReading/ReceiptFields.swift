import Foundation
import BifazModels

/// A value read from a receipt, with how sure the reader is about it.
public struct ReadValue<Value: Sendable & Equatable>: Sendable, Equatable {
    public var value: Value
    public var confidence: ReadingConfidence

    public init(_ value: Value, confidence: ReadingConfidence) {
        self.value = value
        self.confidence = confidence
    }
}

/// One VAT line of a French receipt ("TVA 20 % … base … TVA … TTC").
public struct VATLine: Sendable, Equatable {
    /// Rate as a fraction (0.20).
    public var rate: Decimal
    /// Amount before VAT (HT), when printed.
    public var base: Decimal?
    /// VAT amount, when printed or computable.
    public var vat: Decimal?

    public init(rate: Decimal, base: Decimal? = nil, vat: Decimal? = nil) {
        self.rate = rate
        self.base = base
        self.vat = vat
    }
}

/// What the reader extracted from a receipt. Every field is optional:
/// the confirmation screen shows what was found and asks for the rest.
public struct ReceiptFields: Sendable, Equatable {
    public var merchant: ReadValue<String>?
    public var date: ReadValue<Date>?
    /// Total including VAT (TTC).
    public var total: ReadValue<Decimal>?
    /// ISO 4217 code; Bifaz phase 2 reads EUR receipts.
    public var currencyCode: String
    /// All VAT lines found (receipts can mix 5,5 %, 10 % and 20 %).
    public var vatLines: [VATLine]
    /// The single rate when the receipt has one, else the rate of the largest VAT line.
    public var vatRate: ReadValue<Decimal>?
    /// Total VAT of the receipt.
    public var vatAmount: ReadValue<Decimal>?

    public init(
        merchant: ReadValue<String>? = nil,
        date: ReadValue<Date>? = nil,
        total: ReadValue<Decimal>? = nil,
        currencyCode: String = "EUR",
        vatLines: [VATLine] = [],
        vatRate: ReadValue<Decimal>? = nil,
        vatAmount: ReadValue<Decimal>? = nil
    ) {
        self.merchant = merchant
        self.date = date
        self.total = total
        self.currencyCode = currencyCode
        self.vatLines = vatLines
        self.vatRate = vatRate
        self.vatAmount = vatAmount
    }

    /// Nothing usable was found.
    public var isEmpty: Bool {
        merchant == nil && date == nil && total == nil && vatRate == nil && vatAmount == nil
    }
}

/// The result of reading one receipt.
public struct ReceiptReading: Sendable, Equatable {
    public enum Method: String, Sendable, Equatable {
        /// Apple's on-device model, cross-checked with the rules.
        case model
        /// Rule-based reader only (model unavailable or failed).
        case rules
    }

    /// What happened with Apple's model for this receipt.
    public enum ModelOutcome: String, Sendable, Equatable {
        /// The model answered and its answer was cross-checked with the rules.
        case answered
        /// Not available on this device (or switched off): rules only.
        case unavailable
        /// The model was asked but failed (e.g. not supported in the Simulator): rules only.
        case failed
        /// The model took too long: rules only.
        case timedOut
        /// Not asked (rules forced, or nothing was recognised).
        case notAsked
    }

    public var fields: ReceiptFields
    /// Text lines as recognised, top to bottom (kept for search).
    public var lines: [String]
    public var method: Method
    public var modelOutcome: ModelOutcome
    /// How many of the five fields the model filled in its answer (0 when it did not answer).
    public var modelFieldCount: Int
    /// The model's own answer before cross-checking (diagnostics and measurement only;
    /// the app uses `fields`).
    public var modelFields: ReceiptFields?

    public init(
        fields: ReceiptFields,
        lines: [String],
        method: Method,
        modelOutcome: ModelOutcome = .notAsked,
        modelFieldCount: Int = 0,
        modelFields: ReceiptFields? = nil
    ) {
        self.fields = fields
        self.lines = lines
        self.method = method
        self.modelOutcome = modelOutcome
        self.modelFieldCount = modelFieldCount
        self.modelFields = modelFields
    }

    public var recognizedText: String { lines.joined(separator: "\n") }
}
