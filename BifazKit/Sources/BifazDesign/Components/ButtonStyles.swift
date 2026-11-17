import SwiftUI

/// Full-width near-black button for the main action of a screen.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric private var minHeight: CGFloat = 50

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bifazHeadline)
            .foregroundStyle(Color.bifazPaper)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, BifazSpacing.m)
            .background(Color.bifazInk, in: RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous))
    }
}

/// Full-width outlined button for the secondary action next to a primary one.
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric private var minHeight: CGFloat = 50

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous)
        configuration.label
            .font(.bifazHeadline)
            .foregroundStyle(Color.bifazInk)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, BifazSpacing.m)
            .overlay(shape.strokeBorder(Color.bifazInkSecondary.opacity(0.35), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(shape)
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Near-black, full-width primary button.
    static var bifazPrimary: PrimaryButtonStyle { .init() }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    /// Outlined, full-width secondary button.
    static var bifazSecondary: SecondaryButtonStyle { .init() }
}

#Preview("Light") {
    ButtonStylesSamples()
}

#Preview("Dark") {
    ButtonStylesSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    ButtonStylesSamples().dynamicTypeSize(.accessibility3)
}

private struct ButtonStylesSamples: View {
    var body: some View {
        VStack(spacing: BifazSpacing.xs) {
            Button("Ajouter une dépense") {}
                .buttonStyle(.bifazPrimary)
            Button("Scanner un justificatif") {}
                .buttonStyle(.bifazSecondary)
            Button("Enregistrer") {}
                .buttonStyle(.bifazPrimary)
                .disabled(true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
