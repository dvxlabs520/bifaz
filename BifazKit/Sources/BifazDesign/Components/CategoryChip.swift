import SwiftUI

/// A non-interactive chip that names a category. Same look as `FilterChip`:
/// outlined with the category icon in its tint, or ink-filled when selected.
public struct CategoryChip: View {
    private let name: String
    private let icon: BifazIcon
    private let tint: Color
    private let isSelected: Bool

    public init(_ name: String, icon: BifazIcon, tint: Color, isSelected: Bool = false) {
        self.name = name
        self.icon = icon
        self.tint = tint
        self.isSelected = isSelected
    }

    public var body: some View {
        ChipLabel(title: Text(verbatim: name), icon: icon, symbolTint: tint, isSelected: isSelected)
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
            CategoryChip("Courses", icon: .groceries, tint: .bifazPersonal)
            CategoryChip("Transport", icon: .transport, tint: .bifazPro, isSelected: true)
            CategoryChip("Logiciels", icon: .software, tint: .bifazPro)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
