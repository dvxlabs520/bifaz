import SwiftUI
import BifazModels

/// A pastel circle with a category symbol and, optionally, a small badge in the
/// bottom-trailing corner that tells the space (colour and symbol). Hidden from
/// accessibility: the row that contains it describes the content.
public struct CategoryIcon: View {
    @ScaledMetric private var side: CGFloat

    private let symbolName: String
    private let tint: Color
    private let background: Color
    private let badge: Space?

    public init(symbolName: String, tint: Color, background: Color, badge: Space? = nil, side: CGFloat = 36) {
        self.symbolName = symbolName
        self.tint = tint
        self.background = background
        self.badge = badge
        _side = ScaledMetric(wrappedValue: side, relativeTo: .body)
    }

    private let ring: CGFloat = 2

    public var body: some View {
        Circle()
            .fill(background)
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: side * 0.45, weight: .medium))
                    .foregroundStyle(tint)
            }
            .overlay(alignment: .bottomTrailing) {
                if let badge {
                    badgeView(badge)
                        .offset(x: ring + 1, y: ring + 1)
                }
            }
            .accessibilityHidden(true)
    }

    private func badgeView(_ space: Space) -> some View {
        let diameter = side * 0.42
        return Circle()
            .fill(space.color)
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: space.symbolName)
                    .font(.system(size: diameter * 0.5, weight: .semibold))
                    .foregroundStyle(Color.bifazPaper)
            }
            .padding(ring)
            .background(Color.bifazPaper, in: Circle())
    }
}

#Preview("Light") {
    CategoryIconSamples()
}

#Preview("Dark") {
    CategoryIconSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    CategoryIconSamples().dynamicTypeSize(.accessibility3)
}

private struct CategoryIconSamples: View {
    var body: some View {
        HStack(spacing: BifazSpacing.xl) {
            CategoryIcon(symbolName: "cart.fill", tint: .bifazPersonal, background: .bifazPersonalTint, badge: .personal)
            CategoryIcon(symbolName: "tram.fill", tint: .bifazPro, background: .bifazProTint, badge: .pro)
            CategoryIcon(symbolName: "tag", tint: .bifazInkSecondary, background: .bifazSurfaceMuted)
            CategoryIcon(symbolName: "fork.knife", tint: .bifazPro, background: .bifazProTint, badge: .pro, side: 56)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
