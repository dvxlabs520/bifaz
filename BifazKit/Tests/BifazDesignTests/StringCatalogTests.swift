import Foundation
import Testing

@Suite("String Catalog completeness")
struct StringCatalogTests {
    static let languages = ["en", "es", "fr"]

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    static let catalogs = [
        "BifazKit/Sources/BifazDesign/Resources/Localizable.xcstrings",
        "App/Resources/Localizable.xcstrings",
        "App/Resources/InfoPlist.xcstrings",
        "App/Resources/History.xcstrings",
        "App/Resources/Settings.xcstrings",
        "App/Resources/Summary.xcstrings",
        "App/Resources/Budgets.xcstrings",
    ]

    /// Every `stringUnit` (state, value) under a localization, descending into variations.
    static func units(in node: Any) -> [(state: String?, value: String?)] {
        guard let dict = node as? [String: Any] else { return [] }
        var result: [(String?, String?)] = []
        if let unit = dict["stringUnit"] as? [String: Any] {
            result.append((unit["state"] as? String, unit["value"] as? String))
        }
        if let variations = dict["variations"] as? [String: Any] {
            for (_, group) in variations {
                guard let cases = group as? [String: Any] else { continue }
                for (_, variation) in cases { result += units(in: variation) }
            }
        }
        return result.map { (state: $0.0, value: $0.1) }
    }

    /// Sorted placeholder types (positions ignored) found in `text`.
    static func placeholders(in text: String) -> [String] {
        let pattern = #"%(?:\d+\$)?(?:hh|h|ll|l|z|q|j|t)?[@dDuUxXoOfFeEgGaAcCsSp]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { match in
                var token = ns.substring(with: match.range)
                if let dollar = token.firstIndex(of: "$") {
                    token = "%" + token[token.index(after: dollar)...]
                }
                return token
            }
            .sorted()
    }

    @Test("Catalog is complete in en, es and fr", arguments: catalogs)
    func complete(path: String) throws {
        let url = Self.repoRoot.appending(path: path)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            Issue.record("Catalog does not exist yet: \(path)")
            return
        }
        let data = try Data(contentsOf: url)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any], "\(path) has no 'strings'")
        #expect(!strings.isEmpty, "\(path) has no keys")

        for key in strings.keys.sorted() {
            let entry = strings[key] as? [String: Any] ?? [:]
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            var texts: [String: [String]] = [:]
            for language in Self.languages {
                guard let localization = localizations[language] else {
                    Issue.record("\(path): '\(key)' is missing '\(language)'")
                    continue
                }
                let units = Self.units(in: localization)
                if units.isEmpty {
                    Issue.record("\(path): '\(key)' [\(language)] has no string unit")
                }
                for unit in units {
                    if unit.state != "translated" {
                        Issue.record("\(path): '\(key)' [\(language)] state is '\(unit.state ?? "nil")', expected 'translated'")
                    }
                    if (unit.value ?? "").isEmpty {
                        Issue.record("\(path): '\(key)' [\(language)] has an empty value")
                    }
                }
                texts[language] = units.map { $0.value ?? "" }
            }
        }
    }

    @Test("Placeholders match across translations", arguments: catalogs)
    func placeholdersMatch(path: String) throws {
        let url = Self.repoRoot.appending(path: path)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            Issue.record("Catalog does not exist yet: \(path)")
            return
        }
        let data = try Data(contentsOf: url)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        for key in strings.keys.sorted() {
            let localizations = (strings[key] as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            // Compare each language against English, variation by variation (by value, as a union per language).
            var perLanguage: [String: [String]] = [:]
            for language in Self.languages {
                guard let localization = localizations[language] else { continue }
                let all = Self.units(in: localization).flatMap { Self.placeholders(in: $0.value ?? "") }
                perLanguage[language] = all.sorted()
            }
            // Plural variations may legitimately differ per form, so compare the set of distinct types.
            let reference = Set(perLanguage["en"] ?? [])
            for language in ["es", "fr"] {
                #expect(Set(perLanguage[language] ?? []) == reference,
                        "\(path): '\(key)' placeholders differ between en \(reference.sorted()) and \(language) \(Set(perLanguage[language] ?? []).sorted())")
            }
            // For plain (non-variation) strings, the counts must match exactly.
            let plain = Self.languages.compactMap { lang -> [String]? in
                guard let loc = localizations[lang] as? [String: Any], loc["variations"] == nil,
                      let unit = loc["stringUnit"] as? [String: Any], let v = unit["value"] as? String
                else { return nil }
                return Self.placeholders(in: v)
            }
            if plain.count == Self.languages.count {
                #expect(plain.allSatisfy { $0 == plain[0] },
                        "\(path): '\(key)' placeholder lists differ across languages: \(plain)")
            }
        }
    }
}
