import SwiftUI
import BifazModels

/// The global space selector: three filter chips (All, Pro, Personal), left
/// aligned. At accessibility text sizes the chips wrap into a vertical stack.
/// VoiceOver sees a single picker.
public struct SpaceSelector: View {
    @Binding private var selection: SpaceFilter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let filters: [SpaceFilter] = [.all, .pro, .personal]

    public init(selection: Binding<SpaceFilter>) {
        _selection = selection
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BifazSpacing.xs) { chips }
            VStack(alignment: .leading, spacing: BifazSpacing.xs) { chips }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.15), value: selection)
        // The chips themselves are the accessibility elements (buttons, the chosen one
        // "selected"), grouped under one label. A Picker representation gave VoiceOver
        // frames that did not match the chips (the accessibility audit flagged them).
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("spaceSelector.label", bundle: .module))
    }

    private var chips: some View {
        ForEach(filters) { filter in
            FilterChip(
                filter.title,
                icon: filter.icon,
                symbolTint: filter.space?.color,
                isSelected: selection == filter
            ) { selection = filter }
        }
    }
}

#Preview("Light") {
    SpaceSelectorSamples()
}

#Preview("Dark") {
    SpaceSelectorSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    SpaceSelectorSamples().dynamicTypeSize(.accessibility3)
}

private struct SpaceSelectorSamples: View {
    @State private var first = SpaceFilter.all
    @State private var second = SpaceFilter.pro

    var body: some View {
        VStack(spacing: BifazSpacing.l) {
            SpaceSelector(selection: $first)
            SpaceSelector(selection: $second)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
