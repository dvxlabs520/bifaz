import Foundation
import Testing

/// App views take every colour from BifazDesign tokens (v2 palette, light and dark).
/// A loose colour (`Color.white`, `.black`, `Color(red:…)`) would ignore the warm
/// paper and dark mode, and skip the contrast tests.
@Suite("No loose colours in the app")
struct LooseColorTests {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    static var patterns: [(String, Regex<Substring>)] { [
        ("named SwiftUI colour", try! Regex(#"Color\.(?:white|black|red|blue|green|gray|grey|orange|yellow|purple|pink|brown|cyan|mint|teal|indigo)\b"#)),
        ("system colour shorthand", try! Regex(#"[(:,]\s*\.(?:white|black|red|blue|green|gray|orange|yellow|purple|pink)\b"#)),
        ("raw RGB/HSB colour", try! Regex(#"\b(?:UI)?Color\((?:red|white|hue|displayP3Red):"#)),
    ] }

    @Test("App sources use only BifazDesign colours")
    func noLooseColours() throws {
        let root = Self.repoRoot.appending(path: "App/Sources")
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var checked = 0
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            checked += 1
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines)
            let patterns = Self.patterns
            for (index, line) in lines.enumerated() {
                let code = line.components(separatedBy: "//").first ?? line
                for (kind, pattern) in patterns where code.contains(pattern) {
                    Issue.record("\(url.lastPathComponent):\(index + 1) uses a \(kind): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        #expect(checked > 20)
    }
}
