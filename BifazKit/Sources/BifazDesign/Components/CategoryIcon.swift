import SwiftUI
import BifazModels

/// A pastel circle with a category icon and, optionally, a small badge in the
/// bottom-trailing corner that tells the space (colour and icon). Hidden from
/// accessibility: the row that contains it describes the content.
public struct CategoryIcon: View {
    @ScaledMetric private var side: CGFloat

    private let icon: BifazIcon
    private let tint: Color
    private let background: Color
    private let badge: Space?

    public init(icon: BifazIcon, tint: Color, background: Color, badge: Space? = nil, side: CGFloat = 36) {
        self.icon = icon
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
                icon.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.5, height: side * 0.5)
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
                space.icon.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: diameter * 0.62, height: diameter * 0.62)
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
            CategoryIcon(icon: .groceries, tint: .bifazPersonal, background: .bifazPersonalTint, badge: .personal)
            CategoryIcon(icon: .transport, tint: .bifazPro, background: .bifazProTint, badge: .pro)
            CategoryIcon(icon: .other, tint: .bifazInkSecondary, background: .bifazSurfaceMuted)
            CategoryIcon(icon: .meal, tint: .bifazPro, background: .bifazProTint, badge: .pro, side: 56)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
