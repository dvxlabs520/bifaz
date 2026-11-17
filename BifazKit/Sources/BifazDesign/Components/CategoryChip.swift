import SwiftUI

/// A capsule chip for a category. Selected chips are filled with the tint;
/// unselected chips use a soft tint with ink text.
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
        HStack(spacing: BifazSpacing.xxs) {
            Image(systemName: symbolName)
                .foregroundStyle(isSelected ? Color.bifazPaper : tint)
                .accessibilityHidden(true)
            Text(verbatim: name)
                .foregroundStyle(isSelected ? Color.bifazPaper : Color.bifazInk)
        }
        .font(.bifazLabel)
        .padding(.horizontal, BifazSpacing.s)
        .padding(.vertical, BifazSpacing.xs)
        .background(isSelected ? tint : tint.opacity(0.14), in: Capsule())
        .accessibilityElement(children: .combine)
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
            CategoryChip("Courses", symbolName: "cart.fill", tint: .bifazPersonal, isSelected: true)
            CategoryChip("Transport", symbolName: "tram.fill", tint: .bifazPro)
            CategoryChip("Boulangerie", symbolName: "birthday.cake.fill", tint: .bifazPersonal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
