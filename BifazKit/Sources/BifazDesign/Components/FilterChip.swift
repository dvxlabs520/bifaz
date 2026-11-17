import SwiftUI

/// An outlined capsule chip used to filter lists. The selected chip is filled
/// near-black; an optional icon can carry the colour of a space.
public struct FilterChip: View {
    private let title: LocalizedStringResource
    private let icon: BifazIcon?
    private let symbolTint: Color?
    private let isSelected: Bool
    private let action: @MainActor () -> Void

    public init(
        _ title: LocalizedStringResource,
        icon: BifazIcon? = nil,
        symbolTint: Color? = nil,
        isSelected: Bool,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.symbolTint = symbolTint
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ChipLabel(title: Text(title), icon: icon, symbolTint: symbolTint, isSelected: isSelected)
        }
        .buttonStyle(ChipButtonStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Plain button style that only dims the chip while pressed.
private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#Preview("Light") {
    FilterChipSamples()
}

#Preview("Dark") {
    FilterChipSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    FilterChipSamples().dynamicTypeSize(.accessibility3)
}

private struct FilterChipSamples: View {
    @State private var selected = "Transport"

    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            ForEach(["Courses", "Transport", "Logiciels"], id: \.self) { name in
                FilterChip(
                    LocalizedStringResource(stringLiteral: name),
                    icon: .other,
                    symbolTint: .bifazPro,
                    isSelected: selected == name
                ) { selected = name }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
