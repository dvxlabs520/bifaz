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

/// The Bifaz coin: one coin split in two, the Pro half nudged up and the
/// Personal half nudged down. Square canvas; the coin fills about 70 % of it.
public struct CoinMark: View {
    public enum Palette: Sendable {
        /// Brand colours on cobalt: white Pro half, peach Personal half.
        case brand
        /// Space colours for the current appearance (on Paper or Surface).
        case spaces
        /// Single colour.
        case monochrome(Color)
    }

    private let palette: Palette

    public init(palette: Palette = .brand) {
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
        case .brand:
            Color(uiColor: (half == .pro ? BifazPalette.Brand.coinPro : BifazPalette.Brand.coinPersonal).uiColor)
        case .spaces:
            half == .pro ? .bifazPro : .bifazPersonal
        case .monochrome(let color):
            color
        }
    }
}

/// The app icon drawn in SwiftUI: the brand coin on a cobalt squircle.
/// Same geometry and colours as `AppIcon.icon`, for in-app branding.
public struct BifazAppIcon: View {
    private let side: CGFloat

    public init(side: CGFloat = 64) {
        self.side = side
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
            .fill(Color.bifazBrandCobalt)
            .overlay { CoinMark(palette: .brand) }
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

/// The logotype: app icon and "Bifaz". One accessible element labelled "Bifaz".
public struct BifazWordmark: View {
    @ScaledMetric(relativeTo: .title2) private var iconSide: CGFloat = 40

    public init() {}

    public var body: some View {
        HStack(spacing: BifazSpacing.s) {
            BifazAppIcon(side: iconSide)
            Text(BrandStrings.name)
                .font(.system(.title2, weight: .semibold))
                .foregroundStyle(.bifazInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(BrandStrings.name))
    }
}

#Preview("Light") {
    VStack(spacing: BifazSpacing.xl) {
        BifazAppIcon(side: 120)
        BifazWordmark()
        CoinMark(palette: .spaces).frame(width: 80)
    }
    .padding()
    .background(Color.bifazPaper)
}

#Preview("Dark") {
    VStack(spacing: BifazSpacing.xl) {
        BifazAppIcon(side: 120)
        BifazWordmark()
        CoinMark(palette: .spaces).frame(width: 80)
    }
    .padding()
    .background(Color.bifazPaper)
    .preferredColorScheme(.dark)
}

#Preview("Large text") {
    BifazWordmark()
        .padding()
        .background(Color.bifazPaper)
        .dynamicTypeSize(.accessibility3)
}
