import Foundation
import BifazModels

/// Reads French receipts and invoices with rules, from OCR lines.
///
/// Works on every iPhone and is the fallback when Apple's model is not
/// available. It is also the referee for the model: a value the model
/// returns is only trusted if it can be found in the text (see `ReceiptReader`).
///
/// `lines` come top to bottom; a label and its amount printed on the same row
/// are expected on one line (the OCR step joins them with two spaces).
public enum RuleBasedReceiptParser {
    public static func parse(_ lines: [String], today: Date = .now, calendar: Calendar = .current) -> ReceiptFields {
        let rows = lines.map(Row.init).filter { !$0.folded.isEmpty }
        var fields = ReceiptFields()
        fields.merchant = merchant(in: rows)
        fields.date = date(in: rows, today: today, calendar: calendar)
        let payment = paymentAmount(in: rows)
        let vat = vatSummary(in: rows)
        fields.total = total(in: rows, payment: payment, vat: vat)
        apply(vat, total: fields.total?.value, to: &fields)
        return fields
    }

    // MARK: - Rows

    /// A line with a folded (uppercase, no accents, normalised spaces) copy for matching.
    struct Row {
        let original: String
        let folded: String
        let amounts: [Decimal]
        let rates: [Decimal]

        /// Folded text with punctuation turned into spaces and padded, for whole-word matching.
        let words: String
        /// Amounts with one or two decimals ("12,5"), only trusted on total and payment rows.
        let looseAmounts: [Decimal]

        init(_ text: String) {
            let spaced = text.replacing(/[\u{00A0}\u{202F}\u{2007}\t]/, with: " ")
            original = spaced.trimmingCharacters(in: .whitespaces)
            folded = spaced
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "fr_FR"))
                .uppercased()
                .replacing(/\s+/, with: " ")
                .trimmingCharacters(in: .whitespaces)
            words = " " + folded.replacing(/[^A-Z0-9&°]+/, with: " ") + " "
            let numeric = Self.fixingDigitLookalikes(spaced)
            amounts = Self.amounts(in: numeric)
            looseAmounts = Self.amounts(in: numeric, allowingOneDecimal: true)
            rates = Self.rates(in: numeric)
        }

        /// Substring match on the folded text (for phrases with punctuation).
        func contains(_ words: [String]) -> Bool { words.contains { folded.contains($0) } }

        /// Whole-word match: "TEL" does not match "HOTEL", "ORANGE" matches only the word.
        func containsWord(_ candidates: [String]) -> Bool {
            candidates.contains { words.contains(" \($0) ") }
        }

        /// OCR often reads 0 as the letter O next to digits ("9,5O", "1O%", "O,83").
        static func fixingDigitLookalikes(_ text: String) -> String {
            var characters = Array(text)
            func isNumeric(_ index: Int) -> Bool {
                guard characters.indices.contains(index) else { return false }
                return characters[index].isNumber || characters[index] == "," || characters[index] == "."
            }
            var changed = true
            while changed {
                changed = false
                for index in characters.indices where characters[index] == "O" || characters[index] == "o" {
                    let before = isNumeric(index - 1), after = isNumeric(index + 1)
                    let wordBefore = characters.indices.contains(index - 1) && characters[index - 1].isLetter
                    let wordAfter = characters.indices.contains(index + 1) && characters[index + 1].isLetter
                    if (before || after) && !wordBefore && !wordAfter {
                        characters[index] = "0"
                        changed = true
                    }
                }
            }
            return String(characters)
        }

        /// Money amounts with two decimals ("42,50", "1 234,56", "1.234,56", "42.50"),
        /// excluding percentages, dates and quantities with three decimals.
        /// (Swift Regex has no lookbehind: a leading non-capturing group stands in for it.)
        static func amounts(in text: String, allowingOneDecimal: Bool = false) -> [Decimal] {
            let pattern = allowingOneDecimal
                ? /(?:^|[^\d.,\/:])(\d{1,3}(?:[ .]\d{3})+|\d+) ?[,.] ?(\d{1,2})(?![\d.,\/:%]| ?%)/
                : /(?:^|[^\d.,\/:])(\d{1,3}(?:[ .]\d{3})+|\d+) ?[,.] ?(\d{2})(?![\d.,\/:%]| ?%)/
            return text.matches(of: pattern).compactMap { match in
                let integer = match.output.1.filter(\.isNumber)
                return Decimal(string: "\(integer).\(match.output.2)", locale: Locale(identifier: "en_US_POSIX"))
            }
        }

        /// Known French VAT rates written with a percent sign ("20%", "20,00 %", "5,5%", "2.10%").
        static func rates(in text: String) -> [Decimal] {
            text.matches(of: /(?:^|[^\d,.])(\d{1,2})(?:[,.](\d{1,2}))? ?%/).compactMap { match in
                let value = Decimal(string: "\(match.output.1).\(match.output.2 ?? "0")", locale: Locale(identifier: "en_US_POSIX")) ?? -1
                return knownRates.first { $0 * 100 == value }
            }
        }
    }

    static let knownRates: [Decimal] = VATRate.allCases.map(\.fraction).filter { $0 > 0 }

    // MARK: - Merchant

    static let brands = [
        "MONOPRIX", "CARREFOUR", "FRANPRIX", "LECLERC", "AUCHAN", "INTERMARCHE", "LIDL", "ALDI", "CASINO",
        "PICARD", "NATURALIA", "BIOCOOP", "SNCF", "OUIGO", "RATP", "TOTALENERGIES", "ESSO", "SHELL", "AVIA",
        "FNAC", "DARTY", "IKEA", "DECATHLON", "LEROY MERLIN", "CASTORAMA", "BOULANGER", "AMAZON", "APPLE",
        "ADOBE", "FREE MOBILE", "ORANGE", "SFR", "BOUYGUES", "UBER", "G7", "BOLT", "HEETCH", "STARBUCKS",
        "MCDONALD", "BRIOCHE DOREE", "PAUL", "PHARMACIE", "IBIS", "NOVOTEL", "MERCURE", "AIRBNB", "INDIGO",
        "EFFIA", "SAEMES", "ZARA", "H&M", "SEPHORA", "NESPRESSO", "GOOGLE", "MICROSOFT", "NOTION", "OVH",
    ]

    /// Words (matched whole) that mark a line as address, legal or ticket chrome.
    static let notMerchantWords = [
        "RUE", "AVENUE", "AV", "BD", "BOULEVARD", "PLACE", "ROUTE", "CHEMIN", "ALLEE", "QUAI", "CEDEX",
        "TEL", "TEL:", "FAX", "SIRET", "SIREN", "RCS", "APE", "NAF", "TVA", "TICKET", "FACTURE", "CAISSE",
        "BIENVENUE", "MERCI", "DUPLICATA", "CLIENT", "DATE", "N°", "WWW", "HTTP", "CAPITAL", "VENDEUR",
        "OPERATEUR", "HOTE", "HOTESSE", "TABLE", "COUVERTS", "MAGASIN",
    ]

    /// Lines made only of these words name the trade, not the business ("BOULANGERIE PATISSERIE").
    static let tradeWords: Set<String> = [
        "BOULANGERIE", "PATISSERIE", "BOUCHERIE", "CHARCUTERIE", "TRAITEUR", "EPICERIE", "FINE", "BAR",
        "TABAC", "PRESSE", "CAFE", "RESTAURANT", "BRASSERIE", "PRESSING", "FLEURISTE", "PRIMEUR",
        "SUPERMARCHE", "ALIMENTATION", "GENERALE", "ET", "&", "-",
    ]

    static func merchant(in rows: [Row]) -> ReadValue<String>? {
        // Brands only count in the header (not "jus d'orange" in the articles).
        let header = rows.prefix(6).filter { $0.amounts.isEmpty }
        if let row = header.first(where: { $0.containsWord(brands) }) {
            return ReadValue(cleanMerchant(row.original), confidence: .high)
        }
        let candidate = header.first { row in
            let letters = row.folded.filter(\.isLetter).count
            let digits = row.folded.filter(\.isNumber).count
            let onlyTrade = row.words.split(separator: " ").allSatisfy { tradeWords.contains(String($0)) }
            return letters >= 3 && digits <= 2 && !onlyTrade
                && !row.containsWord(notMerchantWords) && !row.folded.contains("@")
                && row.folded.firstMatch(of: /\d{5}/) == nil
        }
        return candidate.map { ReadValue(cleanMerchant($0.original), confidence: .medium) }
    }

    /// "MONOPRIX  " → "Monoprix"; keeps short acronyms ("SNCF") and mixed case as printed.
    static func cleanMerchant(_ text: String) -> String {
        let trimmed = text
            .replacing(/\*+/, with: "")
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespaces).union(.symbols))
            .replacing(/\s+/, with: " ")
        guard trimmed == trimmed.uppercased() else { return trimmed }
        return trimmed.split(separator: " ").map { word in
            word.count <= 4 && word.allSatisfy(\.isLetter) ? String(word) : word.capitalized(with: Locale(identifier: "fr_FR"))
        }.joined(separator: " ")
    }

    // MARK: - Date

    static let months: [(prefix: String, month: Int)] = [
        ("JANV", 1), ("FEVR", 2), ("FEV", 2), ("MARS", 3), ("AVR", 4), ("MAI", 5), ("JUIN", 6), ("JUIL", 7),
        ("AOUT", 8), ("SEPT", 9), ("OCT", 10), ("NOV", 11), ("DEC", 12),
    ]

    static func date(in rows: [Row], today: Date, calendar: Calendar) -> ReadValue<Date>? {
        var candidates: [(date: Date, score: Int, index: Int)] = []
        for (index, row) in rows.enumerated() {
            for components in dateComponents(in: row.folded) {
                guard let date = calendar.date(from: components) else { continue }
                // Receipts are never in the future, and older than two years is unlikely.
                guard date <= calendar.date(byAdding: .day, value: 1, to: today) ?? today,
                      date >= calendar.date(byAdding: .year, value: -2, to: today) ?? .distantPast else { continue }
                var score = 0
                if row.contains(["DATE DE FACTURE", "DATE DE LA FACTURE", "DATE FACTURE", "FACTURE DU", "EMISE LE", "EMIS LE", "DATE D'EMISSION"]) { score += 30 }
                if row.contains(["DATE", "LE "]) { score += 10 }
                if row.contains(["ECHEANCE", "VALIDITE", "EXPIR", "LIVRAISON", "NAISSANCE", "DEPART", "ARRIVEE", "ECHEANT", "ALLER", "RETOUR"]) { score -= 20 }
                // Invoices that print both: the order date is not the invoice date.
                if row.contains(["DATE DE LA COMMANDE", "DATE DE COMMANDE"]) { score -= 20 }
                candidates.append((date, score, index))
            }
        }
        // Highest score; on a tie, the earliest line (dates are usually printed at the top).
        guard let best = candidates.max(by: { lhs, rhs in
            lhs.score != rhs.score ? lhs.score < rhs.score : lhs.index > rhs.index
        }) else { return nil }
        let distinctDays = Set(candidates.map { calendar.startOfDay(for: $0.date) })
        let confidence: ReadingConfidence = distinctDays.count == 1 || best.score >= 30 ? .high : .medium
        return ReadValue(best.date, confidence: confidence)
    }

    static func dateComponents(in text: String) -> [DateComponents] {
        var result: [DateComponents] = []
        for match in text.matches(of: /(?:^|\D)(\d{1,2})[\/.\-](\d{1,2})[\/.\-](\d{4}|\d{2})(?!\d)/) {
            if let day = Int(match.output.1), let month = Int(match.output.2), var year = Int(match.output.3) {
                if year < 100 { year += 2000 }
                result.append(DateComponents(year: year, month: month, day: day, hour: 12))
            }
        }
        for match in text.matches(of: /(?:^|\D)(\d{4})-(\d{2})-(\d{2})(?!\d)/) {
            if let year = Int(match.output.1), let month = Int(match.output.2), let day = Int(match.output.3) {
                result.append(DateComponents(year: year, month: month, day: day, hour: 12))
            }
        }
        for match in text.matches(of: /(?:^|\D)(\d{1,2})(?:ER)? ([A-Z]{3,9})\.? (\d{4})(?!\d)/) {
            let word = String(match.output.2)
            if let day = Int(match.output.1), let year = Int(match.output.3),
               let month = months.first(where: { word.hasPrefix($0.prefix) })?.month {
                result.append(DateComponents(year: year, month: month, day: day, hour: 12))
            }
        }
        return result.filter { components in
            (1...12).contains(components.month ?? 0) && (1...31).contains(components.day ?? 0)
        }
    }

    // MARK: - Total

    /// Total keywords, strongest first. Matched on folded text with dots removed.
    static let totalKeywords: [(words: String, score: Int)] = [
        ("NET A PAYER", 100), ("TOTAL A PAYER", 98), ("TOTAL TTC", 96), ("MONTANT TTC", 94),
        ("TOTAL T.T.C", 96), ("MONTANT TOTAL", 85), ("A PAYER", 82), ("TOTAL EUR", 78), ("TOTAL €", 78),
        ("MONTANT DU", 76), ("TOTAL", 60),
    ]

    static let notTotalWords = [
        "SOUS-TOTAL", "SOUS TOTAL", "S/TOTAL", "TOTAL HT", "TOTAL H.T", "HORS TAXE", "TOTAL TVA", "TOTAL T.V.A",
        "RENDU", "ESPECES", "MONNAIE", "REMISE", "ECONOMIE", "FIDELITE", "POINTS", "ARTICLE", "NB ART",
        "QTE", "CAGNOTTE", "AVOIR", "TAXE DE SEJOUR",
    ]

    static let paymentWords = ["CB ", "CB:", "CARTE", "VISA", "MASTERCARD", "PAIEMENT", "REGLE", "PAYE ", "SANS CONTACT", "DEBIT"]

    static func paymentAmount(in rows: [Row]) -> Decimal? {
        rows.reversed().first { $0.contains(paymentWords) && !$0.contains(notTotalWords) && !$0.looseAmounts.isEmpty }?.looseAmounts.last
    }

    static func total(in rows: [Row], payment: Decimal?, vat: VATSummary) -> ReadValue<Decimal>? {
        var best: (amount: Decimal, score: Int, index: Int)?
        for (index, row) in rows.enumerated() {
            let text = row.folded.replacing(".", with: "")
            guard !row.contains(notTotalWords),
                  let keyword = totalKeywords.first(where: { text.contains($0.words.replacing(".", with: "")) })
            else { continue }
            // Amount on the same row, else alone on the next row ("TOTAL" / "42,50").
            var amount = row.amounts.last ?? row.looseAmounts.last
            if amount == nil, index + 1 < rows.count {
                let next = rows[index + 1]
                let isPlainAmount = next.looseAmounts.count == 1 && next.rates.isEmpty
                    && next.folded.filter(\.isLetter).count <= 4 && !next.containsWord(["TVA", "HT", "CB", "RENDU"])
                if isPlainAmount { amount = next.looseAmounts.first }
            }
            guard let amount, amount > 0 else { continue }
            if best == nil || keyword.score > best!.score || (keyword.score == best!.score && index > best!.index) {
                best = (amount, keyword.score, index)
            }
        }

        if let best {
            let corroborated = best.amount == payment || vat.consistentTotal == best.amount
            let confidence: ReadingConfidence = best.score >= 90 || corroborated ? .high : best.score >= 60 ? .medium : .low
            return ReadValue(best.amount, confidence: confidence)
        }
        if let payment { return ReadValue(payment, confidence: .medium) }
        if let total = vat.consistentTotal { return ReadValue(total, confidence: .medium) }
        // Last resort: the largest amount on the receipt.
        return rows.flatMap(\.amounts).max().map { ReadValue($0, confidence: .low) }
    }

    // MARK: - VAT

    struct VATSummary {
        var lines: [VATLine] = []
        /// "TOTAL TVA 7,08" when printed.
        var printedTotalVAT: Decimal?
        /// Base + VAT of the table, when every line has both.
        var consistentTotal: Decimal?
        /// "TVA non applicable, art. 293 B du CGI".
        var notApplicable = false
    }

    static func vatSummary(in rows: [Row]) -> VATSummary {
        var summary = VATSummary()
        for row in rows {
            if row.contains(["293 B", "293B", "TVA NON APPLICABLE", "EXONERATION DE TVA", "EXONERE DE TVA"]) {
                summary.notApplicable = true
                continue
            }
            if row.rates.isEmpty {
                if row.contains(["TOTAL TVA", "TOTAL T.V.A", "MONTANT TVA", "MONTANT DE LA TVA", "DONT TVA"]), let amount = row.amounts.last {
                    summary.printedTotalVAT = amount
                }
                continue
            }
            guard let rate = row.rates.first else { continue }
            let mentionsVAT = row.contains(["TVA", "T.V.A", "TAXE"])
            if let line = vatLine(rate: rate, amounts: row.amounts, mentionsVAT: mentionsVAT),
               !summary.lines.contains(where: { $0.rate == line.rate && $0.vat == line.vat }) {
                summary.lines.append(line)
            }
        }
        // Keep one line per rate (the first, usually the table).
        var seen = Set<Decimal>()
        summary.lines = summary.lines.filter { seen.insert($0.rate).inserted }
        if !summary.lines.isEmpty, summary.lines.allSatisfy({ $0.base != nil && $0.vat != nil }) {
            summary.consistentTotal = summary.lines.reduce(Decimal(0)) { $0 + ($1.base ?? 0) + ($1.vat ?? 0) }.rounded(scale: 2)
        }
        return summary
    }

    /// Interprets the amounts on a row that carries a VAT rate.
    static func vatLine(rate: Decimal, amounts: [Decimal], mentionsVAT: Bool) -> VATLine? {
        func close(_ a: Decimal, _ b: Decimal) -> Bool { abs((a - b).rounded(scale: 2)) <= Decimal(string: "0.02")! }
        // (base, vat) pair where vat ≈ base × rate, in any order; ignores a TTC column.
        for base in amounts {
            for vat in amounts where vat < base && close((base * rate).rounded(scale: 2), vat) {
                return VATLine(rate: rate, base: base, vat: vat)
            }
        }
        // (vat, ttc) pair where vat ≈ ttc − ttc / (1 + rate).
        for ttc in amounts {
            for vat in amounts where vat < ttc && close(VATCalculator.vatAmount(includedIn: ttc, rate: rate), vat) {
                return VATLine(rate: rate, base: (ttc - vat).rounded(scale: 2), vat: vat)
            }
        }
        // "TVA 10% : 2,05" or "dont TVA 20% 3,50": a single amount is the VAT.
        if mentionsVAT, amounts.count == 1, let vat = amounts.first {
            return VATLine(rate: rate, vat: vat)
        }
        if mentionsVAT, amounts.isEmpty { return VATLine(rate: rate) }
        return nil
    }

    static func apply(_ vat: VATSummary, total: Decimal?, to fields: inout ReceiptFields) {
        if vat.notApplicable, vat.lines.isEmpty {
            fields.vatRate = ReadValue(0, confidence: .high)
            fields.vatAmount = ReadValue(0, confidence: .high)
            return
        }
        guard !vat.lines.isEmpty else {
            if let printed = vat.printedTotalVAT { fields.vatAmount = ReadValue(printed, confidence: .medium) }
            return
        }
        fields.vatLines = vat.lines
        let verified = vat.lines.allSatisfy { $0.base != nil && $0.vat != nil }

        if vat.lines.count == 1, let line = vat.lines.first {
            fields.vatRate = ReadValue(line.rate, confidence: verified ? .high : .medium)
        } else if let main = vat.lines.max(by: { ($0.vat ?? 0) < ($1.vat ?? 0) }) {
            fields.vatRate = ReadValue(main.rate, confidence: .medium)
        }

        let summed = vat.lines.compactMap(\.vat).reduce(Decimal(0), +).rounded(scale: 2)
        if let printed = vat.printedTotalVAT {
            fields.vatAmount = ReadValue(printed, confidence: printed == summed ? .high : .medium)
        } else if vat.lines.allSatisfy({ $0.vat != nil }) {
            fields.vatAmount = ReadValue(summed, confidence: verified ? .high : .medium)
        } else if vat.lines.count == 1, let rate = vat.lines.first?.rate, let total {
            fields.vatAmount = ReadValue(VATCalculator.vatAmount(includedIn: total, rate: rate), confidence: .medium)
        }
    }
}
