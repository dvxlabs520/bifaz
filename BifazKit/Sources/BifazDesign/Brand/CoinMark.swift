import SwiftUI

/// One half of the coin as a SwiftUI shape.
public struct CoinHalfShape: Shape {
    public let half: CoinGeometry.Half

    public init(_ half: CoinGeometry.Half) { self.half = half }

    public func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let transform = CGAffineTransform(translationX: origin.x, y: origin.y)
        return Path(CoinGeometry.path(for: half, size: side)).applying(transform)
    }
}

/// The Bifaz coin: cobalt Pro half and terracotta Personal half.
///
/// The canvas is square; the coin fills about 70 % of it, leaving the same
/// breathing room as the app icon.
public struct CoinMark: View {
    public enum Palette: Sendable {
        /// Space colours for the current appearance (use on Paper or Surface).
        case adaptive
        /// Bright space colours, for use on the brand ink (launch, splash, icon).
        case onInk
        /// Single colour (tinted contexts).
        case monochrome(Color)
    }

    private let palette: Palette

    public init(palette: Palette = .adaptive) {
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            CoinHalfShape(.pro).fill(color(for: .pro))
            CoinHalfShape(.personal).fill(color(for: .personal))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func color(for half: CoinGeometry.Half) -> Color {
        switch palette {
        case .adaptive:
            half == .pro ? .bifazPro : .bifazPersonal
        case .onInk:
            Color(uiColor: (half == .pro ? BifazPalette.pro : BifazPalette.personal).dark.uiColor)
        case .monochrome(let color):
            color
        }
    }
}

/// The logotype: the coin beside the initial B, then "Bifaz" in New York.
/// Rendered as one accessible element labelled "Bifaz". Scales with Dynamic Type.
public struct BifazWordmark: View {
    public enum Size: Sendable {
        case large
        case medium

        var font: Font {
            switch self {
            case .large: .system(.largeTitle, design: .serif, weight: .semibold)
            case .medium: .system(.title2, design: .serif, weight: .semibold)
            }
        }
    }

    private let size: Size
    private let palette: CoinMark.Palette
    private let textColor: Color
    @ScaledMetric private var coinSide: CGFloat
    @ScaledMetric private var gap: CGFloat

    public init(size: Size = .large, palette: CoinMark.Palette = .adaptive, textColor: Color = .bifazInk) {
        self.size = size
        self.palette = palette
        self.textColor = textColor
        switch size {
        case .large:
            _coinSide = ScaledMetric(wrappedValue: 44, relativeTo: .largeTitle)
            _gap = ScaledMetric(wrappedValue: 2, relativeTo: .largeTitle)
        case .medium:
            _coinSide = ScaledMetric(wrappedValue: 30, relativeTo: .title2)
            _gap = ScaledMetric(wrappedValue: 1, relativeTo: .title2)
        }
    }

    public var body: some View {
        HStack(alignment: .center, spacing: gap) {
            CoinMark(palette: palette)
                .frame(width: coinSide, height: coinSide)
            Text(BrandStrings.name)
                .font(size.font)
                .foregroundStyle(textColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(BrandStrings.name))
    }
}
