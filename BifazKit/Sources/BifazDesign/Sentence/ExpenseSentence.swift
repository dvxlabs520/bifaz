import Foundation
import BifazModels

/// One piece of the entry sentence: words to read, or a value to tap.
public struct SentencePiece: Identifiable, Equatable, Sendable {
    public enum Role: String, Sendable, CaseIterable {
        /// Plain words between the values ("I spent", "at", "·").
        case words
        case amount, merchant, category, space, date
    }

    public let role: Role
    public let text: String
    /// The value is not set yet: a neutral filler ("a shop") is shown.
    public let isPlaceholder: Bool
    /// Full VoiceOver label ("Amount, €42.00"); empty for words.
    public let accessibilityLabel: String
    /// Position in the sentence (stable identity for SwiftUI).
    public let index: Int

    public var id: Int { index }
    public var isTappable: Bool { role != .words }
    /// Words that start with punctuation (", en") join the previous piece without a space.
    public var attachesToPrevious: Bool {
        role == .words && (text.first.map { ",.;:".contains($0) } ?? false)
    }
}

/// What the sentence says.
public struct ExpenseSentenceInput: Equatable, Sendable {
    public var amount: Decimal?
    public var currencyCode: String
    public var merchant: String
    public var categoryName: String?
    public var space: Space
    public var date: Date

    public init(amount: Decimal?, currencyCode: String = "EUR", merchant: String, categoryName: String?, space: Space, date: Date) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.merchant = merchant
        self.categoryName = categoryName
        self.space = space
        self.date = date
    }
}

/// The new-expense sentence (PLAN.md §3): "I spent €42.00 at Carrefour on
/// Groceries · Personal · today". Each language writes its own sentence from a
/// template in the catalog (`sentence.template`) with the slots {amount},
/// {merchant}, {category}, {space} and {date} in any order, so French and English
/// are not word-for-word translations of the Spanish.
public enum ExpenseSentence {
    public static func pieces(
        _ input: ExpenseSentenceInput,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [SentencePiece] {
        let template = LocalizedStringResource("sentence.template", bundle: .module).resolved(in: locale)
        var pieces: [SentencePiece] = []
        var rest = Substring(template)
        while !rest.isEmpty {
            guard let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") else {
                append(words: String(rest), to: &pieces)
                break
            }
            append(words: String(rest[..<open]), to: &pieces)
            let slot = String(rest[rest.index(after: open)..<close])
            if let role = SentencePiece.Role(rawValue: slot), role != .words {
                pieces.append(piece(role, input: input, index: pieces.count, now: now, calendar: calendar, locale: locale))
            }
            rest = rest[rest.index(after: close)...]
        }
        return pieces
    }

    private static func append(words: String, to pieces: inout [SentencePiece]) {
        let trimmed = words.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        pieces.append(SentencePiece(role: .words, text: trimmed, isPlaceholder: false, accessibilityLabel: "", index: pieces.count))
    }

    private static func piece(_ role: SentencePiece.Role, input: ExpenseSentenceInput, index: Int, now: Date,
                              calendar: Calendar, locale: Locale) -> SentencePiece {
        let empty = LocalizedStringResource("sentence.ax.empty", bundle: .module).resolved(in: locale)
        func make(_ text: String, placeholder: Bool, label: LocalizedStringResource) -> SentencePiece {
            SentencePiece(role: role, text: text, isPlaceholder: placeholder, accessibilityLabel: label.resolved(in: locale), index: index)
        }
        switch role {
        case .amount:
            let value = (input.amount ?? 0).formatted(.currency(code: input.currencyCode).locale(locale))
            let spoken = input.amount == nil ? empty : value
            return make(value, placeholder: input.amount == nil, label: LocalizedStringResource("sentence.ax.amount \(spoken)", bundle: .module))
        case .merchant:
            let name = input.merchant.trimmingCharacters(in: .whitespaces)
            let filler = LocalizedStringResource("sentence.placeholder.merchant", bundle: .module).resolved(in: locale)
            return make(name.isEmpty ? filler : name, placeholder: name.isEmpty,
                        label: LocalizedStringResource("sentence.ax.merchant \(name.isEmpty ? empty : name)", bundle: .module))
        case .category:
            let name = input.categoryName ?? ""
            let filler = LocalizedStringResource("sentence.placeholder.category", bundle: .module).resolved(in: locale)
            return make(name.isEmpty ? filler : name, placeholder: name.isEmpty,
                        label: LocalizedStringResource("sentence.ax.category \(name.isEmpty ? empty : name)", bundle: .module))
        case .space:
            let name = input.space.title.resolved(in: locale)
            return make(name, placeholder: false, label: LocalizedStringResource("sentence.ax.space \(name)", bundle: .module))
        case .date:
            let text = dateText(input.date, now: now, calendar: calendar, locale: locale)
            return make(text, placeholder: false, label: LocalizedStringResource("sentence.ax.date \(text)", bundle: .module))
        case .words:
            return make("", placeholder: false, label: "")
        }
    }

    /// The sentence as plain text (spaces between pieces, none before punctuation).
    public static func plainText(_ pieces: [SentencePiece]) -> String {
        pieces.reduce(into: "") { text, piece in
            if !text.isEmpty, !piece.attachesToPrevious { text += " " }
            text += piece.text
        }
    }

    /// "today", "yesterday", "on 3 Nov" (with the year when it is not this year).
    public static func dateText(_ date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return LocalizedStringResource("sentence.date.today", bundle: .module).resolved(in: locale)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return LocalizedStringResource("sentence.date.yesterday", bundle: .module).resolved(in: locale)
        }
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated)
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) { style = style.year() }
        let day = date.formatted(style)
        return LocalizedStringResource("sentence.date.on \(day)", bundle: .module).resolved(in: locale)
    }
}
