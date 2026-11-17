import SwiftUI

/// An outlined capsule chip used to filter lists. The selected chip is filled
/// near-black; an optional SF Symbol can carry the colour of a space.
public struct FilterChip: View {
    private let title: LocalizedStringResource
    private let symbolName: String?
    private let symbolTint: Color?
    private let isSelected: Bool
    private let action: @MainActor () -> Void

    public init(
        _ title: LocalizedStringResource,
        symbolName: String? = nil,
        symbolTint: Color? = nil,
        isSelected: Bool,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.symbolName = symbolName
        self.symbolTint = symbolTint
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ChipLabel(title: Text(title), symbolName: symbolName, symbolTint: symbolTint, isSelected: isSelected)
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
                    symbolName: "tag.fill",
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
