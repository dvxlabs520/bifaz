import SwiftUI
import BifazModels
import BifazDesign

// Bridges between stored models and design-system components.

extension ExpenseCategory {
    /// The category's icon (falls back to `.other` for unknown names).
    var icon: BifazIcon { BifazIcon(rawValue: iconName) ?? .other }

    /// Name in the current language for built-in categories, else the user's name.
    var displayName: String { displayName(localize: CategoryNames.current) }
}

/// Default category names, from the app's String Catalog.
enum CategoryNames {
    /// In the app's current language.
    static func current(_ seedKey: String) -> String {
        Bundle.main.localizedString(forKey: seedKey, value: nil, table: nil)
    }

    /// Every shipped translation of a default name (to recognise names stored
    /// by earlier builds in another language).
    static func allTranslations(_ seedKey: String) -> Set<String> {
        var names: Set<String> = [current(seedKey)]
        for language in Bundle.main.localizations {
            guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { continue }
            let name = bundle.localizedString(forKey: seedKey, value: nil, table: nil)
            if name != seedKey { names.insert(name) }
        }
        return names
    }
}

extension Expense {
    /// Merchant, else category name, else "Expense".
    var displayTitle: String {
        if !merchant.isEmpty { return merchant }
        if let name = category?.displayName, !name.isEmpty { return name }
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
            categoryName: hasMerchant ? expense.category?.displayName : String(localized: "expense.noMerchant"),
            categoryIcon: expense.category?.icon,
            date: expense.date,
            amount: expense.amountInEUR,
            currencyCode: "EUR",
            space: expense.space,
            receiptState: expense.receiptState,
            originalAmount: expense.isForeignCurrency ? (expense.amount, expense.currencyCode) : nil
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

extension VATPart {
    /// "20 %", "8,5 %" for a rate outside the French list, or "Rate not detailed"
    /// for a v1 receipt with several rates.
    var rateText: String {
        guard let rate else { return String(localized: "vat.rate.unknown") }
        return VATRate(fraction: rate)?.percentText
            ?? (rate as NSDecimalNumber).doubleValue.formatted(.percent.precision(.fractionLength(0...1)))
    }
}

/// Whether the user charges VAT ("Sujeto a TVA"); hides VAT fields when false.
enum VATSetting {
    static let key = "isVATRegistered"
    static let defaultValue = true
}
