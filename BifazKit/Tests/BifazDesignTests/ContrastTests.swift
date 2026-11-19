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

@Suite("Palette v2 (editorial cálida)")
struct PaletteV2Tests {
    @Test("Paper, surface, hairline and inks keep the plan's starting values")
    func planValues() {
        #expect(BifazPalette.paper.light == RGB(0xF4F1EA) && BifazPalette.paper.dark == RGB(0x14130F))
        #expect(BifazPalette.surface.light == RGB(0xFBFAF6) && BifazPalette.surface.dark == RGB(0x1D1B17))
        #expect(BifazPalette.hairline.light == RGB(0xE4DFD4) && BifazPalette.hairline.dark == RGB(0x2E2A23))
        #expect(BifazPalette.ink.light == RGB(0x1A1814) && BifazPalette.ink.dark == RGB(0xF3EFE6))
        #expect(BifazPalette.inkSecondary.light == RGB(0x6B655A) && BifazPalette.inkSecondary.dark == RGB(0xA39C8F))
    }

    @Test("Paper is warm, not white: red above blue")
    func warmPaper() {
        #expect(BifazPalette.paper.light.red > BifazPalette.paper.light.blue)
        #expect(BifazPalette.paper.light != RGB(0xFFFFFF))
    }
}

@Suite("Hero amount parts")
struct AmountPartsTests {
    @Test("Whole part, cents and suffix", arguments: [
        ("1 284,50 €", ",", "1 284", ",50", " €"),
        ("€1,284.50", ".", "€1,284", ".50", ""),
        ("-12,00 €", ",", "-12", ",00", " €"),
        ("¥1,280", ".", "¥1,280", "", ""),
        ("CHF 22.80", ".", "CHF 22", ".80", ""),
        ("0,00 €", ",", "0", ",00", " €"),
    ])
    func parts(formatted: String, separator: String, whole: String, decimals: String, suffix: String) {
        let parts = AmountParts(formatted: formatted, decimalSeparator: separator)
        #expect(parts == AmountParts(whole: whole, decimals: decimals, suffix: suffix))
        #expect(parts.whole + parts.decimals + parts.suffix == formatted)
    }
}
