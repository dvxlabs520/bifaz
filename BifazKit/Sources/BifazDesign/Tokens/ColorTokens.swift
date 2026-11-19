import SwiftUI
import UIKit
import BifazModels

// MARK: - Raw values

/// An sRGB colour stored as `0xRRGGBB`. Kept as plain numbers so tests can
/// check contrast without going through UIKit.
public struct RGB: Hashable, Sendable, CustomStringConvertible {
    public let hex: UInt32

    public init(_ hex: UInt32) { self.hex = hex }

    public var red: Double { Double((hex >> 16) & 0xFF) / 255 }
    public var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    public var blue: Double { Double(hex & 0xFF) / 255 }

    public var description: String { String(format: "#%06X", hex) }

    public var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

/// A design token with a value for light and dark appearance.
public struct ColorToken: Hashable, Sendable, Identifiable {
    public let name: String
    public let light: RGB
    public let dark: RGB

    public var id: String { name }

    public init(_ name: String, light: UInt32, dark: UInt32) {
        self.name = name
        self.light = RGB(light)
        self.dark = RGB(dark)
    }

    public func value(for style: UIUserInterfaceStyle) -> RGB {
        style == .dark ? dark : light
    }

    /// Dynamic colour that follows the current appearance.
    public var uiColor: UIColor {
        let light = light.uiColor, dark = dark.uiColor
        return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    public var color: Color { Color(uiColor: uiColor) }
}

// MARK: - Palette

/// Bifaz colour tokens, v2 "editorial cálida" (PLAN.md §3, phase 5).
///
/// Warm paper instead of white, thin warm hairlines, a warm near-black ink; colour
/// only carries meaning: the space (Pro cobalt, Personal terracotta) and status
/// (success, warning, error). Every text pair passes WCAG AA, checked in
/// `ContrastTests`.
///
/// Paper, Surface, Hairline, Ink and Ink secondary use the plan's starting values
/// unchanged. Adjusted for AA on the warm paper (light only): Personal `#B8451A` →
/// `#B24319`, Success `#1B7F50` → `#19764A`, Warning `#98641A` → `#8D5D18`, Error
/// `#C4314B` → `#BE3049`. Surface muted (new warm value) `#ECE8DF` / `#26231E`.
public enum BifazPalette {
    /// Main text, primary buttons, selected filter.
    public static let ink = ColorToken("ink", light: 0x1A1814, dark: 0xF3EFE6)
    /// Secondary text: subtitles, dates, captions, the decimals of a hero amount.
    public static let inkSecondary = ColorToken("inkSecondary", light: 0x6B655A, dark: 0xA39C8F)
    /// Screen background: warm paper.
    public static let paper = ColorToken("paper", light: 0xF4F1EA, dark: 0x14130F)
    /// Cards and sheets (bordered with `hairline`).
    public static let surface = ColorToken("surface", light: 0xFBFAF6, dark: 0x1D1B17)
    /// Quiet fills: progress tracks, pressed rows, round header buttons, neutral circles.
    public static let surfaceMuted = ColorToken("surfaceMuted", light: 0xECE8DF, dark: 0x26231E)
    /// 1 pt borders and dividers. Decorative, never used for text.
    public static let hairline = ColorToken("hairline", light: 0xE4DFD4, dark: 0x2E2A23)

    /// Everything that belongs to the Pro space.
    public static let pro = ColorToken("pro", light: 0x2747D8, dark: 0x8AA2FF)
    /// Everything that belongs to the Personal space.
    public static let personal = ColorToken("personal", light: 0xB24319, dark: 0xFF9466)
    public static let success = ColorToken("success", light: 0x19764A, dark: 0x5BD69A)
    public static let warning = ColorToken("warning", light: 0x8D5D18, dark: 0xF2C261)
    public static let error = ColorToken("error", light: 0xBE3049, dark: 0xFF8097)

    /// Pastel fills behind icons (category circles, status badges).
    public static let proTint = ColorToken("proTint", light: 0xECEFFC, dark: 0x1E2747)
    public static let personalTint = ColorToken("personalTint", light: 0xF9EEE8, dark: 0x3A2419)
    public static let successTint = ColorToken("successTint", light: 0xEEF7F2, dark: 0x15301F)
    public static let warningTint = ColorToken("warningTint", light: 0xFFF3DC, dark: 0x3A2E14)
    public static let errorTint = ColorToken("errorTint", light: 0xFBE9EC, dark: 0x3A1A20)

    /// Brand colours that never change with appearance (app icon, launch screen, splash).
    public enum Brand {
        /// Icon and launch background.
        public static let cobalt = RGB(0x2747D8)
        /// Pro half of the coin on cobalt.
        public static let coinPro = RGB(0xFFFFFF)
        /// Personal half of the coin on cobalt.
        public static let coinPersonal = RGB(0xFFB08A)
    }

    public static let all: [ColorToken] = [
        ink, inkSecondary, paper, surface, surfaceMuted, hairline,
        pro, personal, success, warning, error,
        proTint, personalTint, successTint, warningTint, errorTint,
    ]

    /// Tokens used as text colour.
    public static let textTokens: [ColorToken] = [
        ink, inkSecondary, pro, personal, success, warning, error,
    ]
    /// Tokens used as background behind text.
    public static let backgroundTokens: [ColorToken] = [paper, surface, surfaceMuted]

    /// Every text-on-background pair the interface uses, checked for AA in tests:
    /// text tokens on every background, Paper on filled controls (Ink buttons and
    /// chips, Pro and Personal badges) and status/space colours on their tints.
    public static let contrastPairs: [(text: ColorToken, background: ColorToken)] =
        textTokens.flatMap { text in backgroundTokens.map { (text, $0) } }
        + [
            (paper, ink), (paper, pro), (paper, personal),
            (pro, proTint), (personal, personalTint), (success, successTint),
            (warning, warningTint), (error, errorTint),
        ]
}

// MARK: - SwiftUI access

public extension Color {
    static let bifazInk = BifazPalette.ink.color
    static let bifazInkSecondary = BifazPalette.inkSecondary.color
    static let bifazPaper = BifazPalette.paper.color
    static let bifazSurface = BifazPalette.surface.color
    static let bifazSurfaceMuted = BifazPalette.surfaceMuted.color
    static let bifazHairline = BifazPalette.hairline.color
    static let bifazPro = BifazPalette.pro.color
    static let bifazPersonal = BifazPalette.personal.color
    static let bifazSuccess = BifazPalette.success.color
    static let bifazWarning = BifazPalette.warning.color
    static let bifazError = BifazPalette.error.color
    static let bifazProTint = BifazPalette.proTint.color
    static let bifazPersonalTint = BifazPalette.personalTint.color
    static let bifazSuccessTint = BifazPalette.successTint.color
    static let bifazWarningTint = BifazPalette.warningTint.color
    static let bifazErrorTint = BifazPalette.errorTint.color
    /// Brand cobalt, identical in light and dark (icon, launch screen).
    static let bifazBrandCobalt = Color(uiColor: BifazPalette.Brand.cobalt.uiColor)
}

public extension ShapeStyle where Self == Color {
    static var bifazInk: Color { .bifazInk }
    static var bifazInkSecondary: Color { .bifazInkSecondary }
    static var bifazPaper: Color { .bifazPaper }
    static var bifazSurface: Color { .bifazSurface }
    static var bifazSurfaceMuted: Color { .bifazSurfaceMuted }
    static var bifazHairline: Color { .bifazHairline }
    static var bifazPro: Color { .bifazPro }
    static var bifazPersonal: Color { .bifazPersonal }
    static var bifazSuccess: Color { .bifazSuccess }
    static var bifazWarning: Color { .bifazWarning }
    static var bifazError: Color { .bifazError }
}

public extension Space {
    /// The space's identity colour. Always pair it with text or an icon.
    var color: Color {
        switch self {
        case .pro: .bifazPro
        case .personal: .bifazPersonal
        }
    }

    /// Pastel fill behind the space's icons.
    var tint: Color {
        switch self {
        case .pro: .bifazProTint
        case .personal: .bifazPersonalTint
        }
    }

    /// Icon that identifies the space without relying on colour.
    var icon: BifazIcon {
        switch self {
        case .pro: .pro
        case .personal: .personal
        }
    }
}

public extension SpaceFilter {
    /// Accent colour for the filter: the space colour, or Ink for "All".
    var color: Color {
        space?.color ?? .bifazInk
    }

    /// Icon that identifies the filter: the space icon, or the Bifaz coin for "All".
    var icon: BifazIcon {
        space?.icon ?? .all
    }
}
