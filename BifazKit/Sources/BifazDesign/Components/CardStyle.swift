import SwiftUI

public extension View {
    /// Wraps the view in a Bifaz card: surface fill, a 1 pt hairline border and
    /// small continuous corners. No shadow; cards are used sparingly.
    func bifazCard(padding: CGFloat = BifazSpacing.m) -> some View {
        let shape = RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous)
        return self
            .padding(padding)
            .background(Color.bifazSurface, in: shape)
            .overlay(shape.strokeBorder(Color.bifazHairline, lineWidth: 1))
    }
}

/// A 1 pt hairline that separates content, optionally inset from the leading
/// edge so it lines up with the text of a row.
public struct HairlineDivider: View {
    private let leadingInset: CGFloat

    public init(leadingInset: CGFloat = 0) {
        self.leadingInset = leadingInset
    }

    public var body: some View {
        Rectangle()
            .fill(Color.bifazHairline)
            .frame(height: 1)
            .padding(.leading, leadingInset)
            .accessibilityHidden(true)
    }
}

#Preview("Light") {
    CardStyleSamples()
}

#Preview("Dark") {
    CardStyleSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    CardStyleSamples().dynamicTypeSize(.accessibility3)
}

private struct CardStyleSamples: View {
    var body: some View {
        VStack(spacing: BifazSpacing.m) {
            Text(verbatim: "Monoprix")
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bifazCard()
            VStack(spacing: 0) {
                Text(verbatim: "SNCF")
                    .font(.bifazBody)
                    .foregroundStyle(Color.bifazInk)
                    .padding(.vertical, BifazSpacing.s)
                HairlineDivider()
                Text(verbatim: "Boulangerie Paul")
                    .font(.bifazBody)
                    .foregroundStyle(Color.bifazInkSecondary)
                    .padding(.vertical, BifazSpacing.s)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
