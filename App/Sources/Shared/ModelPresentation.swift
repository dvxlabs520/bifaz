import SwiftUI
import BifazModels
import BifazDesign

// Bridges between stored models and design-system components.

extension ExpenseCategory {
    /// The category's icon (falls back to `.other` for unknown names).
    var icon: BifazIcon { BifazIcon(rawValue: iconName) ?? .other }
}

extension Expense {
    /// Merchant, else category name, else "Expense".
    var displayTitle: String {
        if !merchant.isEmpty { return merchant }
        if let name = category?.name, !name.isEmpty { return name }
        return String(localized: "expense.untitled")
    }

    var receiptState: ReceiptThumbnail.State {
        if receipt != nil { return .attached }
        return status == .receiptPending ? .pending : .none
    }
}

extension ExpenseRow {
    /// A row for a stored expense. Without a merchant, the category becomes
    /// the title (or "Expense" when there is none either).
    init(_ expense: Expense) {
        let hasMerchant = !expense.merchant.isEmpty
        self.init(
            merchant: hasMerchant ? expense.merchant : expense.displayTitle,
            categoryName: hasMerchant ? expense.category?.name : String(localized: "expense.noMerchant"),
            categoryIcon: expense.category?.icon,
            date: expense.date,
            amount: expense.amountInEUR,
            currencyCode: "EUR",
            space: expense.space,
            receiptState: expense.receiptState
        )
    }
}

extension ExpenseSource {
    var title: LocalizedStringResource {
        switch self {
        case .manual: "source.manual"
        case .scanner: "source.scanner"
        case .applePay: "source.applePay"
        case .recurring: "source.recurring"
        }
    }
}

extension ExpenseStatus {
    var title: LocalizedStringResource {
        switch self {
        case .confirmed: "status.confirmed"
        case .needsReview: "status.needsReview"
        case .receiptPending: "status.receiptPending"
        }
    }
}

extension VATRate {
    /// "20 %", "5,5 %"… in the current locale.
    var percentText: String {
        (fraction as NSDecimalNumber).doubleValue
            .formatted(.percent.precision(.fractionLength(0...1)))
    }
}

/// Whether the user charges VAT ("Sujeto a TVA"); hides VAT fields when false.
enum VATSetting {
    static let key = "isVATRegistered"
    static let defaultValue = true
}
