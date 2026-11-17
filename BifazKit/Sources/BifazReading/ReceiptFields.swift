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

    public var fields: ReceiptFields
    /// Text lines as recognised, top to bottom (kept for search).
    public var lines: [String]
    public var method: Method

    public init(fields: ReceiptFields, lines: [String], method: Method) {
        self.fields = fields
        self.lines = lines
        self.method = method
    }

    public var recognizedText: String { lines.joined(separator: "\n") }
}
