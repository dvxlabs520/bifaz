import CoreGraphics
import Foundation

/// The single source of truth for the Bifaz coin: one coin split vertically
/// into two halves, the Pro half (left) nudged up and the Personal half
/// (right) nudged down. Together they read as one full circle.
///
/// All values are fractions of a square canvas. The SwiftUI mark, the app
/// icon SVGs and the launch image are all produced from these numbers
/// (`BifazDesignTests` checks that the committed SVGs match `svgPath`).
public enum CoinGeometry {
    /// Coin radius.
    public static let radius: Double = 0.34
    /// Half of the horizontal gap between the halves.
    public static let halfGap: Double = 0.024
    /// Vertical offset of each half (Pro up, Personal down).
    public static let shift: Double = 0.045

    public enum Half: CaseIterable, Sendable {
        /// Left half, cobalt.
        case pro
        /// Right half, terracotta.
        case personal
    }

    /// Centre of a half's circle in unit coordinates (y grows downwards).
    public static func center(of half: Half) -> CGPoint {
        switch half {
        case .pro: CGPoint(x: 0.5 - halfGap, y: 0.5 - shift)
        case .personal: CGPoint(x: 0.5 + halfGap, y: 0.5 + shift)
        }
    }

    /// The half as a closed path, scaled to a square canvas of side `size`.
    public static func path(for half: Half, size: CGFloat) -> CGPath {
        let c = center(of: half)
        let center = CGPoint(x: c.x * size, y: c.y * size)
        let r = radius * size
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x, y: center.y - r))
        // Pro sweeps through the left side, Personal through the right.
        // In a y-down space, `clockwise: false` sweeps visually clockwise.
        path.addArc(
            center: center,
            radius: r,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: half == .pro
        )
        path.closeSubpath()
        return path
    }

    /// SVG path data for a half on a canvas of side `size` (y-down, like SVG).
    public static func svgPath(for half: Half, size: Double) -> String {
        let c = center(of: half)
        let cx = c.x * size, cy = c.y * size, r = radius * size
        let sweep = half == .pro ? 0 : 1
        return "M\(fmt(cx)) \(fmt(cy - r)) A\(fmt(r)) \(fmt(r)) 0 0 \(sweep) \(fmt(cx)) \(fmt(cy + r)) Z"
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
