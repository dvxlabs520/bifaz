import SwiftUI

/// A non-interactive chip that names a category. Same look as `FilterChip`:
/// outlined with the category symbol in its tint, or ink-filled when selected.
public struct CategoryChip: View {
    private let name: String
    private let symbolName: String
    private let tint: Color
    private let isSelected: Bool

    public init(_ name: String, symbolName: String, tint: Color, isSelected: Bool = false) {
        self.name = name
        self.symbolName = symbolName
        self.tint = tint
        self.isSelected = isSelected
    }

    public var body: some View {
        ChipLabel(title: Text(verbatim: name), symbolName: symbolName, symbolTint: tint, isSelected: isSelected)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: name))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Light") {
    CategoryChipSamples()
}

#Preview("Dark") {
    CategoryChipSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    CategoryChipSamples().dynamicTypeSize(.accessibility3)
}

private struct CategoryChipSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            CategoryChip("Courses", symbolName: "cart.fill", tint: .bifazPersonal)
            CategoryChip("Transport", symbolName: "tram.fill", tint: .bifazPro, isSelected: true)
            CategoryChip("Logiciels", symbolName: "app.fill", tint: .bifazPro)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
