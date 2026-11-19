import Foundation

/// The letter shown in a merchant's avatar (v2 lists): its initial on the space's
/// tint. No brand logos (they need brand permission and a connection).
public enum Monogram {
    /// The first letter or digit of the name, upper-cased with its accent kept
    /// ("éclair" → "É", "« Le Zinc »" → "L", "7-Eleven" → "7"), or "·" for an empty
    /// or symbol-only name.
    public static func initial(for name: String, locale: Locale = .current) -> String {
        let character = name.first { character in
            guard let scalar = character.unicodeScalars.first else { return false }
            return CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
        }
        guard let character else { return "·" }
        return String(character).uppercased(with: locale)
    }
}
