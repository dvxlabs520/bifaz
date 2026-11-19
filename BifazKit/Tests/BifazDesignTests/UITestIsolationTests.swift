import Foundation
import Testing

/// XCTest's UI API (`XCUIElement.frame`, `.label`…) is main-actor isolated, but using
/// it from a nonisolated function is only a *warning* — the compiler keeps it a warning
/// even with warnings-as-errors. This check makes it fail instead: every function of
/// the UI tests (except XCTest's own overrides) must be marked `@MainActor`.
@Suite("UI tests run on the main actor")
struct UITestIsolationTests {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test("Every UI test function is @MainActor")
    func mainActor() throws {
        let folder = Self.repoRoot.appending(path: "UITests")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        let declaration = try Regex(#"^\s*(?:(?:private|fileprivate|static|final)\s+)*func\s"#)
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() where line.contains(declaration) {
                if line.contains("override func") { continue }
                let previous = lines[..<index].last { !$0.trimmingCharacters(in: .whitespaces).isEmpty
                    && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
                #expect(previous?.contains("@MainActor") == true,
                        "\(file.lastPathComponent):\(index + 1) is not @MainActor: \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }
}
