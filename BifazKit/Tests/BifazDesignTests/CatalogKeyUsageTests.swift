import Foundation
import Testing

/// Every localization key written in code must exist in a String Catalog,
/// otherwise the raw key ("tab.summary") would show on screen.
///
/// Keys are recognised as dotted string literals whose first component is a
/// namespace already used by some catalog key ("tab", "form", "history"…), so
/// asset names, bundle ids and UTIs are ignored. Interpolations become `%@`.
@Suite("Catalog keys used in code")
struct CatalogKeyUsageTests {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // BifazDesignTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // BifazKit
        .deletingLastPathComponent() // repo root

    static let sourceFolders = ["App/Sources", "BifazKit/Sources"]

    static func catalogKeys() throws -> Set<String> {
        var keys = Set<String>()
        let folders = ["App/Resources", "BifazKit/Sources/BifazDesign/Resources"]
        for folder in folders {
            let url = repoRoot.appending(path: folder)
            let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "xcstrings" {
                let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
                let strings = json?["strings"] as? [String: Any] ?? [:]
                keys.formUnion(strings.keys)
            }
        }
        return keys
    }

    /// Dotted literals in Swift sources, with `\(…)` interpolations turned into `%@`.
    static func keysUsedInCode() throws -> [(key: String, file: String)] {
        let literal = try Regex(#""([a-z][A-Za-z]*(?:\.[A-Za-z]+)+(?: \\\(.*?\))*)""#)
        var found: [(String, String)] = []
        for folder in sourceFolders {
            let root = repoRoot.appending(path: folder)
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = enumerator?.nextObject() as? URL {
                guard url.pathExtension == "swift" else { continue }
                let text = try String(contentsOf: url, encoding: .utf8)
                for match in text.matches(of: literal) {
                    guard let raw = match.output[1].substring else { continue }
                    let key = replacingInterpolations(in: String(raw))
                    found.append((key, url.lastPathComponent))
                }
            }
        }
        return found
    }

    /// Turns each balanced `\(…)` into `%@`.
    static func replacingInterpolations(in text: String) -> String {
        var result = ""
        var depth = 0
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if depth == 0, character == "\\", next < text.endIndex, text[next] == "(" {
                result += "%@"
                depth = 1
                index = text.index(after: next)
                continue
            }
            if depth > 0 {
                if character == "(" { depth += 1 }
                if character == ")" { depth -= 1 }
            } else {
                result.append(character)
            }
            index = next
        }
        return result
    }

    /// Placeholders differ by type (`%@`, `%lld`, `%1$@`); compare keys without them.
    static func normalized(_ key: String) -> String {
        key.replacing(/%(\d+\$)?(@|lld|ld|d|f|lf)/, with: "%")
    }

    @Test("Every key used in code exists in a catalog")
    func everyUsedKeyExists() throws {
        let keys = try Self.catalogKeys()
        let normalizedKeys = Set(keys.map(Self.normalized))
        let namespaces = Set(keys.compactMap { $0.split(separator: ".").first.map(String.init) })
        let used = try Self.keysUsedInCode().filter { usage in
            namespaces.contains(String(usage.key.split(separator: ".").first ?? ""))
        }
        #expect(!used.isEmpty, "No keys found: the scanner is broken")
        for usage in used where !normalizedKeys.contains(Self.normalized(usage.key)) {
            Issue.record("Missing catalog key \"\(usage.key)\" used in \(usage.file)")
        }
    }
}
