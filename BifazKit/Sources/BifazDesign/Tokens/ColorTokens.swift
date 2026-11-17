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

/// Bifaz colour tokens (PLAN.md §3, "Colores").
///
/// Deviations from the plan, both forced by WCAG AA (4.5:1 on Paper):
/// - Success light `#1E8E5A` → `#1B7F50` (was 3.74:1 on Paper).
/// - Warning light `#B7791F` → `#98641A` (was 3.29:1 on Paper).
/// `inkSecondary` is an addition: secondary text needs a quieter ink that still passes AA.
public enum BifazPalette {
    /// Main text and primary buttons.
    public static let ink = ColorToken("ink", light: 0x10151D, dark: 0xF2EFE8)
    /// Secondary text (captions, metadata).
    public static let inkSecondary = ColorToken("inkSecondary", light: 0x5E6571, dark: 0xA3A9B4)
    /// App background.
    public static let paper = ColorToken("paper", light: 0xF6F3EC, dark: 0x0B1018)
    /// Cards and sheets.
    public static let surface = ColorToken("surface", light: 0xFFFFFF, dark: 0x151C27)
    /// Everything that belongs to the Pro space.
    public static let pro = ColorToken("pro", light: 0x2747D8, dark: 0x8AA2FF)
    /// Everything that belongs to the Personal space.
    public static let personal = ColorToken("personal", light: 0xB8451A, dark: 0xFF9466)
    public static let success = ColorToken("success", light: 0x1B7F50, dark: 0x5BD69A)
    public static let warning = ColorToken("warning", light: 0x98641A, dark: 0xF2C261)
    public static let error = ColorToken("error", light: 0xC4314B, dark: 0xFF8097)

    /// Brand ink that never changes with appearance (launch screen, icon, splash).
    public static let brandInk = RGB(0x10151D)

    public static let all: [ColorToken] = [
        ink, inkSecondary, paper, surface, pro, personal, success, warning, error,
    ]

    /// Tokens used as text colour.
    public static let textTokens: [ColorToken] = [
        ink, inkSecondary, pro, personal, success, warning, error,
    ]
    /// Tokens used as background behind text.
    public static let backgroundTokens: [ColorToken] = [paper, surface]

    /// Every text-on-background pair the interface uses, checked for AA in tests.
    /// Includes the inverted pairs used by filled controls (Paper text on Ink,
    /// Pro and Personal fills).
    public static let contrastPairs: [(text: ColorToken, background: ColorToken)] =
        textTokens.flatMap { text in backgroundTokens.map { (text, $0) } }
        + [(paper, ink), (paper, pro), (paper, personal)]
}

// MARK: - SwiftUI access

public extension Color {
    static let bifazInk = BifazPalette.ink.color
    static let bifazInkSecondary = BifazPalette.inkSecondary.color
    static let bifazPaper = BifazPalette.paper.color
    static let bifazSurface = BifazPalette.surface.color
    static let bifazPro = BifazPalette.pro.color
    static let bifazPersonal = BifazPalette.personal.color
    static let bifazSuccess = BifazPalette.success.color
    static let bifazWarning = BifazPalette.warning.color
    static let bifazError = BifazPalette.error.color
    /// Ink that stays dark in both appearances.
    static let bifazBrandInk = Color(uiColor: BifazPalette.brandInk.uiColor)
    /// Hairlines and dividers (non-text, decorative).
    static let bifazHairline = BifazPalette.ink.color.opacity(0.12)
}

public extension ShapeStyle where Self == Color {
    static var bifazInk: Color { .bifazInk }
    static var bifazInkSecondary: Color { .bifazInkSecondary }
    static var bifazPaper: Color { .bifazPaper }
    static var bifazSurface: Color { .bifazSurface }
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

    /// SF Symbol that identifies the space without relying on colour.
    var symbolName: String {
        switch self {
        case .pro: "briefcase.fill"
        case .personal: "house.fill"
        }
    }
}

public extension SpaceFilter {
    /// Accent colour for the filter: the space colour, or Ink for "All".
    var color: Color {
        space?.color ?? .bifazInk
    }

    var symbolName: String {
        space?.symbolName ?? "circle.lefthalf.filled"
    }
}
