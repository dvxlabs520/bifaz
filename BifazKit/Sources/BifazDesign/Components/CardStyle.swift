import SwiftUI

public extension View {
    /// Wraps the view in a Bifaz card: solid surface, continuous medium corners
    /// and a hairline border. Cards are never glass; glass is reserved for bars
    /// and floating controls.
    func bifazCard(padding: CGFloat = BifazSpacing.m) -> some View {
        let shape = RoundedRectangle(cornerRadius: BifazRadius.medium, style: .continuous)
        return self
            .padding(padding)
            .background(Color.bifazSurface, in: shape)
            .overlay(shape.strokeBorder(Color.bifazHairline, lineWidth: 1))
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
                .font(.bifazHeadline)
                .foregroundStyle(Color.bifazInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bifazCard()
            Text(verbatim: "Boulangerie Paul")
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bifazCard(padding: BifazSpacing.l)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bifazPaper)
    }
}
