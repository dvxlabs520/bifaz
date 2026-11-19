import Foundation
import Testing

/// The "+" menu items: present in the three languages and short enough to fit a
/// menu line without iOS hyphenating a word ("Gasto sin justifican-te").
@Suite("Capture menu strings")
struct CaptureMenuStringsTests {
    static let keys = ["capture.scan", "capture.photo", "capture.file", "capture.manual"]
    /// Longest label overall (two menu lines at most at the default text size).
    static let maxLength = 25
    /// What fits on one menu line next to its icon at the default size on a 6.1" iPhone.
    static let oneLine = 18
    /// When a label needs two lines, a longer word gets hyphenated by iOS
    /// ("Gasto sin justificante" → "Gasto sin justifican-te").
    static let maxWordWhenWrapping = 9

    @Test("Each menu item exists in en, es and fr, translated and short", arguments: keys)
    func item(key: String) throws {
        let url = StringCatalogTests.repoRoot.appending(path: "App/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let entry = try #require((json?["strings"] as? [String: Any])?[key] as? [String: Any], "\(key) is missing")
        let localizations = try #require(entry["localizations"] as? [String: Any])
        for language in StringCatalogTests.languages {
            let unit = (localizations[language] as? [String: Any])?["stringUnit"] as? [String: Any]
            let value = try #require(unit?["value"] as? String, "\(key) has no \(language) value")
            #expect(unit?["state"] as? String == "translated", "\(key) [\(language)] is not translated")
            #expect(!value.isEmpty)
            #expect(value.count <= Self.maxLength, "\(key) [\(language)] is too long: \(value)")
            if value.count > Self.oneLine {
                let longest = value.split(whereSeparator: \.isWhitespace).map(\.count).max() ?? 0
                #expect(longest <= Self.maxWordWhenWrapping,
                        "\(key) [\(language)] wraps and has a word iOS would hyphenate: \(value)")
            }
        }
    }
}
