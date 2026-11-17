import Foundation

/// French VAT (TVA) rates.
public enum VATRate: String, CaseIterable, Codable, Sendable, Identifiable {
    /// 20 %, most goods and services.
    case standard
    /// 10 %, restaurants, transport, some works.
    case intermediate
    /// 5,5 %, food, energy, books.
    case reduced
    /// 2,1 %, press, some medicines.
    case superReduced
    /// No VAT on the receipt.
    case zero

    public var id: String { rawValue }

    /// The rate as a fraction (0.20 for 20 %).
    public var fraction: Decimal {
        switch self {
        case .standard: Decimal(string: "0.20")!
        case .intermediate: Decimal(string: "0.10")!
        case .reduced: Decimal(string: "0.055")!
        case .superReduced: Decimal(string: "0.021")!
        case .zero: 0
        }
    }

    /// The rate matching a stored fraction, if it is one of the French rates.
    public init?(fraction: Decimal) {
        guard let match = Self.allCases.first(where: { $0.fraction == fraction }) else { return nil }
        self = match
    }
}

/// VAT arithmetic on amounts that include VAT (TTC), rounded to the cent.
public enum VATCalculator {
    /// VAT included in `total`: total − total / (1 + rate).
    public static func vatAmount(includedIn total: Decimal, rate: Decimal) -> Decimal {
        guard rate > 0, total > 0 else { return 0 }
        return (total - total / (1 + rate)).rounded(scale: 2)
    }

    /// Amount before VAT (HT).
    public static func amountExcludingVAT(_ total: Decimal, rate: Decimal) -> Decimal {
        (total - vatAmount(includedIn: total, rate: rate)).rounded(scale: 2)
    }
}
