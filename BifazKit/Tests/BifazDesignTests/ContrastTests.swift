import Foundation
import Testing
@testable import BifazDesign

/// WCAG 2.x relative luminance and contrast ratio.
enum WCAG {
    static func linearise(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    static func luminance(_ color: RGB) -> Double {
        0.2126 * linearise(color.red) + 0.7152 * linearise(color.green) + 0.0722 * linearise(color.blue)
    }

    static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

struct ContrastCase: Sendable, CustomTestStringConvertible {
    let text: ColorToken
    let background: ColorToken
    let isDark: Bool

    var appearance: String { isDark ? "dark" : "light" }
    var textValue: RGB { isDark ? text.dark : text.light }
    var backgroundValue: RGB { isDark ? background.dark : background.light }
    var testDescription: String { "\(text.name) on \(background.name) (\(appearance))" }

    static let all: [ContrastCase] = BifazPalette.contrastPairs.flatMap { pair in
        [false, true].map { ContrastCase(text: pair.text, background: pair.background, isDark: $0) }
    }
}

@Suite("WCAG contrast")
struct ContrastTests {
    @Test("Contrast maths matches known references")
    func references() {
        #expect(abs(WCAG.ratio(RGB(0x000000), RGB(0xFFFFFF)) - 21) < 1e-9)
        #expect(abs(WCAG.ratio(RGB(0xFFFFFF), RGB(0x000000)) - 21) < 1e-9)
        #expect(abs(WCAG.ratio(RGB(0x336699), RGB(0x336699)) - 1) < 1e-9)
        // #767676 on white is the well-known 4.54:1 AA threshold grey.
        let grey = WCAG.ratio(RGB(0x767676), RGB(0xFFFFFF))
        #expect(grey > 4.5 && grey < 4.6)
        #expect(abs(WCAG.luminance(RGB(0xFFFFFF)) - 1) < 1e-9)
        #expect(WCAG.luminance(RGB(0x000000)) == 0)
    }

    @Test("The palette defines contrast pairs")
    func pairsExist() {
        #expect(ContrastCase.all.count == BifazPalette.contrastPairs.count * 2)
        #expect(!ContrastCase.all.isEmpty)
    }

    @Test("Pair meets WCAG AA (4.5:1)", arguments: ContrastCase.all)
    func meetsAA(_ pair: ContrastCase) {
        let ratio = WCAG.ratio(pair.textValue, pair.backgroundValue)
        #expect(
            ratio >= 4.5,
            "\(pair.text.name) (\(pair.textValue)) on \(pair.background.name) (\(pair.backgroundValue)) in \(pair.appearance): \(String(format: "%.2f", ratio)):1 < 4.5:1"
        )
    }
}
