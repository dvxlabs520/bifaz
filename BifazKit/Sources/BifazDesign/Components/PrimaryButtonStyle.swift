import SwiftUI

/// The main call-to-action button: full width, Ink fill, Paper label.
/// Presses scale it slightly (not with Reduce Motion); disabled dims it.
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Bifaz primary button.
    static var bifazPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

private struct PrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var minHeight: CGFloat = 52

    var body: some View {
        configuration.label
            .font(.bifazHeadline)
            .foregroundStyle(Color.bifazPaper)
            .multilineTextAlignment(.center)
            .padding(.horizontal, BifazSpacing.m)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color.bifazInk, in: RoundedRectangle(cornerRadius: BifazRadius.medium, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview("Light") {
    PrimaryButtonSamples()
}

#Preview("Dark") {
    PrimaryButtonSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    PrimaryButtonSamples().dynamicTypeSize(.accessibility3)
}

private struct PrimaryButtonSamples: View {
    var body: some View {
        VStack(spacing: BifazSpacing.m) {
            Button("Scanner un ticket") {}
                .buttonStyle(.bifazPrimary)
            Button("Enregistrer") {}
                .buttonStyle(.bifazPrimary)
                .disabled(true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bifazPaper)
    }
}
