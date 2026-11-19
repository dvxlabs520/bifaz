import SwiftUI
import BifazModels

/// The merchant's avatar in v2 lists: a circle in the space's tint with the
/// merchant's initial in ink and the small space badge of
/// `CategoryIcon`. Hidden from accessibility: the row says the merchant.
public struct MonogramAvatar: View {
    @Environment(\.locale) private var locale
    @ScaledMetric private var side: CGFloat

    private let name: String
    private let space: Space
    private let ring: CGFloat = 2

    public init(name: String, space: Space, side: CGFloat = 36) {
        self.name = name
        self.space = space
        _side = ScaledMetric(wrappedValue: side, relativeTo: .body)
    }

    public var body: some View {
        Circle()
            .fill(space.tint)
            .frame(width: side, height: side)
            .overlay {
                Text(verbatim: Monogram.initial(for: name, locale: locale))
                    .font(.system(size: side * 0.44, weight: .semibold))
                    // Ink, not the space colour: a small glyph on the tint needs the
                    // margin (the badge already says the space).
                    .foregroundStyle(Color.bifazInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .overlay(alignment: .bottomTrailing) {
                badge
                    .offset(x: ring + 1, y: ring + 1)
            }
            .accessibilityHidden(true)
    }

    private var badge: some View {
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
    MonogramAvatarSamples()
}

#Preview("Dark") {
    MonogramAvatarSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    MonogramAvatarSamples().dynamicTypeSize(.accessibility3)
}

private struct MonogramAvatarSamples: View {
    var body: some View {
        HStack(spacing: BifazSpacing.xl) {
            MonogramAvatar(name: "Boulangerie Paul", space: .personal)
            MonogramAvatar(name: "SNCF", space: .pro)
            MonogramAvatar(name: "Éclair & Cie", space: .personal)
            MonogramAvatar(name: "Mercadona", space: .personal)
            MonogramAvatar(name: "Ferretería López", space: .pro, side: 56)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
