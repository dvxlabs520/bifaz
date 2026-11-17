import SwiftUI
import BifazModels
import BifazDesign

/// The app's exchange-rate service (one table on disk, shared by every form).
enum ExchangeRates {
    static let service = ExchangeRateService(
        fileURL: (try? ExchangeRateService.defaultFileURL())
            ?? FileManager.default.temporaryDirectory.appending(path: "ecb-rates.json")
    )

    /// Currencies the ECB publishes (fixed list, so the picker works offline).
    static let ecbCurrencies = [
        "USD", "GBP", "CHF", "CAD", "JPY", "AUD", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "RON", "ISK", "TRY",
        "BRL", "CNY", "HKD", "IDR", "ILS", "INR", "KRW", "MXN", "MYR", "NZD", "PHP", "SGD", "THB", "ZAR",
    ]

    /// Downloads are allowed: the setting is on and this is not a UI test run.
    static var downloadsAllowed: Bool {
        let on = AppDefaults.shared.object(forKey: ExchangeRateSetting.key) as? Bool ?? ExchangeRateSetting.defaultValue
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "BifazUITesting") { return false }
        #endif
        return on
    }

    static func name(of code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code).map { "\($0) (\(code))" } ?? code
    }
}

/// A rate as typed: "1,0989" or "1.0989", up to 10 decimals.
enum RateParser {
    static func parse(_ text: String) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isNumber || $0 == "." }),
              let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { return nil }
        return value.rounded(scale: 10)
    }
}

/// The currency next to the amount: euro by default, the ECB currencies, or another code (manual rate).
struct CurrencyMenu: View {
    @Binding var currencyCode: String
    @State private var isTypingOther = false
    @State private var otherCode = ""

    private var symbol: String {
        currencyCode == "EUR" ? Locale.current.currencySymbol(for: "EUR") : currencyCode
    }

    var body: some View {
        Menu {
            Button(ExchangeRates.name(of: "EUR")) { currencyCode = "EUR" }
            Divider()
            ForEach(ExchangeRates.ecbCurrencies, id: \.self) { code in
                Button(ExchangeRates.name(of: code)) { currencyCode = code }
            }
            Divider()
            Button("form.currency.other") {
                otherCode = ""
                isTypingOther = true
            }
        } label: {
            HStack(spacing: BifazSpacing.xxs) {
                Text(verbatim: symbol)
                    .font(currencyCode == "EUR" ? .bifazAmountHero : .bifazSectionTitle)
                BifazIconView(.chevronDown, size: 14)
            }
            .foregroundStyle(.bifazInkSecondary)
            .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel(Text("form.currency \(ExchangeRates.name(of: currencyCode))"))
        .accessibilityIdentifier("ui.formCurrency")
        .alert("form.currency.other", isPresented: $isTypingOther) {
            TextField(text: $otherCode) { Text(verbatim: "ISO 4217") }
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("form.currency.use") {
                let code = otherCode.uppercased().filter(\.isLetter)
                if code.count == 3 { currencyCode = code }
            }
            Button("tags.picker.cancel", role: .cancel) {}
        } message: {
            Text("form.currency.other.message")
        }
    }
}

private extension Locale {
    func currencySymbol(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = self
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol
    }
}

/// Under the amount of a foreign-currency expense: the euros, the rate and where
/// it comes from, with the rate or the euro amount editable. Never blocks saving
/// on the network: without a rate, it asks for one.
struct ConversionPanel: View {
    @Binding var draft: ExpenseDraft
    /// The last lookup (nil while looking up or when nothing was found).
    let lookup: ExchangeRateService.Lookup?
    let isLookingUp: Bool

    @State private var editsRate = false
    @State private var editsEuros = false
    @State private var rateText = ""
    @State private var eurosText = ""

    private static let rateStyle = Decimal.FormatStyle.number.precision(.fractionLength(0...6))
    private static let amountStyle = Decimal.FormatStyle.number.precision(.fractionLength(2)).grouping(.never)

    private var hasRate: Bool { draft.amountInEUR != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            if let euros = draft.amountInEUR {
                Text("form.currency.euros \(euros.formatted(.currency(code: "EUR")))")
                    .font(.bifazSectionTitle)
                    .monospacedDigit()
                    .foregroundStyle(.bifazInk)
                    .accessibilityIdentifier("ui.formEuros")
            }
            caption
            if !hasRate || editsRate || editsEuros {
                inputs
            } else {
                HStack(spacing: BifazSpacing.m) {
                    Button("form.currency.editRate") { startEditingRate() }
                        .accessibilityIdentifier("ui.formEditRate")
                    Button("form.currency.editEuros") { startEditingEuros() }
                        .accessibilityIdentifier("ui.formEditEuros")
                }
                .font(.bifazCaption)
                .foregroundStyle(.bifazInk)
                .buttonStyle(.plain)
            }
        }
        .padding(BifazSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bifazSurfaceMuted, in: RoundedRectangle(cornerRadius: BifazRadius.small))
        .onChange(of: draft.currencyCode) {
            editsRate = false
            editsEuros = false
            rateText = ""
            eurosText = ""
        }
    }

    @ViewBuilder
    private var caption: some View {
        let code = draft.currencyCode
        if isLookingUp {
            Text("form.currency.lookingUp")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
        } else if draft.amountInEUROverride != nil {
            Text("form.currency.bankAmount")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
        } else if let quote = draft.exchangeRate, quote.currencyCode == code {
            let rate = quote.rate.formatted(Self.rateStyle)
            let day = quote.date.formatted(.dateTime.day().month(.abbreviated))
            Group {
                switch quote.source {
                case .ecb: Text("form.currency.rate.ecb \(rate) \(code) \(day)")
                case .ecbApproximate: Text("form.currency.rate.approximate \(rate) \(code) \(day)")
                case .manual: Text("form.currency.rate.manual \(rate) \(code)")
                }
            }
            .font(.bifazCaption)
            .foregroundStyle(quote.source == .ecbApproximate ? .bifazWarning : .bifazInkSecondary)
            if quote.source != .manual, lookup?.isFromStoredTable == true, let downloaded = lookup?.tableDownloadedAt {
                Text("form.currency.storedTable \(downloaded.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            }
        } else {
            Text("form.currency.noRate")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
        }
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            HStack(spacing: BifazSpacing.xs) {
                Text(verbatim: "1 € =")
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInkSecondary)
                TextField(text: $rateText, prompt: Text(verbatim: "1,0000")) { Text("form.currency.rateField") }
                    .keyboardType(.decimalPad)
                    .font(.bifazBody.monospacedDigit())
                    .fixedSize()
                    .accessibilityIdentifier("ui.formRate")
                Text(verbatim: draft.currencyCode)
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInkSecondary)
            }
            HStack(spacing: BifazSpacing.xs) {
                Text("form.currency.orEuros")
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInkSecondary)
                TextField(text: $eurosText, prompt: Text(verbatim: "0,00")) { Text("form.currency.eurosField") }
                    .keyboardType(.decimalPad)
                    .font(.bifazBody.monospacedDigit())
                    .fixedSize()
                    .accessibilityIdentifier("ui.formAmountEUR")
                Text(verbatim: "€")
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInkSecondary)
            }
        }
        .onChange(of: rateText) { _, text in
            guard let rate = RateParser.parse(text) else { return }
            draft.amountInEUROverride = nil
            eurosText = ""
            draft.exchangeRate = ExchangeRateQuote(currencyCode: draft.currencyCode, rate: rate, date: draft.date, source: .manual)
        }
        .onChange(of: eurosText) { _, text in
            draft.amountInEUROverride = MoneyParser.parse(text)
            if draft.amountInEUROverride != nil { rateText = "" }
        }
    }

    private func startEditingRate() {
        rateText = draft.exchangeRate.map { $0.rate.formatted(Self.rateStyle) } ?? ""
        editsRate = true
    }

    private func startEditingEuros() {
        eurosText = draft.amountInEUR.map { $0.formatted(Self.amountStyle) } ?? ""
        editsEuros = true
    }
}
