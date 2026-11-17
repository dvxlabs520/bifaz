import CoreGraphics
import Foundation
import Testing
@testable import BifazDesign

@Suite("Coin geometry")
struct CoinGeometryTests {
    /// `<root>/BifazKit/Tests/BifazDesignTests/<this file>` -> `<root>`.
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // BifazDesignTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // BifazKit
            .deletingLastPathComponent() // root
    }

    @Test("App icon SVG matches CoinGeometry", arguments: [
        (CoinGeometry.Half.pro, "coin-pro.svg"),
        (CoinGeometry.Half.personal, "coin-personal.svg"),
    ])
    func svgMatches(half: CoinGeometry.Half, file: String) throws {
        let url = Self.repoRoot.appending(path: "App/AppIcon.icon/Assets/\(file)")
        let svg = try String(contentsOf: url, encoding: .utf8)
        let expected = CoinGeometry.svgPath(for: half, size: 1024)
        #expect(svg.contains(expected), "\(file) does not contain \(expected)")
    }

    @Test("Both halves share the same radius")
    func sameRadius() {
        let pro = CoinGeometry.path(for: .pro, size: 1000).boundingBoxOfPath
        let personal = CoinGeometry.path(for: .personal, size: 1000).boundingBoxOfPath
        // Each half spans the full diameter vertically.
        #expect(abs(pro.height - personal.height) < 1e-6)
        #expect(abs(pro.height - 2 * CoinGeometry.radius * 1000) < 1e-6)
        #expect(abs(pro.width - personal.width) < 1e-6)
        #expect(abs(pro.width - CoinGeometry.radius * 1000) < 1e-6)
    }

    @Test("Halves are mirror images around the canvas centre")
    func mirrored() {
        let pro = CoinGeometry.center(of: .pro)
        let personal = CoinGeometry.center(of: .personal)
        #expect(abs(pro.x + personal.x - 1) < 1e-12)
        #expect(abs(pro.y + personal.y - 1) < 1e-12)
        #expect(pro.y < personal.y, "Pro sits up, Personal sits down")
    }

    @Test("Coin fits inside the canvas with a margin", arguments: CoinGeometry.Half.allCases)
    func fits(half: CoinGeometry.Half) {
        let box = CoinGeometry.path(for: half, size: 1).boundingBoxOfPath
        #expect(box.minX >= 0.1 && box.maxX <= 0.9, "x extents \(box.minX)…\(box.maxX)")
        #expect(box.minY >= 0.1 && box.maxY <= 0.9, "y extents \(box.minY)…\(box.maxY)")
    }
}
