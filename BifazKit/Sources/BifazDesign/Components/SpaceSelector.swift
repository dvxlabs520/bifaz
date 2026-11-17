import SwiftUI
import BifazModels

/// The global space selector: a custom segmented control with Pro, Personal
/// and All. The selected option is a capsule in the filter's colour that
/// slides between options (no animation with Reduce Motion). At accessibility
/// text sizes the options stack vertically so nothing truncates.
public struct SpaceSelector: View {
    @Binding private var selection: SpaceFilter
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(selection: Binding<SpaceFilter>) {
        _selection = selection
    }

    public var body: some View {
        layout {
            ForEach(SpaceFilter.allCases) { filter in
                option(filter)
            }
        }
        .padding(BifazSpacing.xxs)
        .background(Color.bifazSurface, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.bifazHairline, lineWidth: 1))
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityRepresentation {
            Picker(selection: $selection) {
                ForEach(SpaceFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            } label: {
                Text("spaceSelector.label", bundle: .module)
            }
        }
    }

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: BifazSpacing.xxs))
            : AnyLayout(HStackLayout(spacing: BifazSpacing.xxs))
    }

    private func option(_ filter: SpaceFilter) -> some View {
        let isSelected = filter == selection
        return Button {
            selection = filter
        } label: {
            HStack(spacing: BifazSpacing.xxs) {
                Image(systemName: filter.symbolName)
                    .imageScale(.small)
                Text(filter.title)
                    .multilineTextAlignment(.center)
            }
            .font(.bifazSubheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.bifazPaper : Color.bifazInkSecondary)
            .padding(.vertical, BifazSpacing.xs)
            .padding(.horizontal, BifazSpacing.s)
            .frame(maxWidth: .infinity, minHeight: BifazSpacing.xxl)
            .background {
                if isSelected {
                    Capsule()
                        .fill(filter.color)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
    @State private var first = SpaceFilter.pro
    @State private var second = SpaceFilter.personal

    var body: some View {
        VStack(spacing: BifazSpacing.l) {
            SpaceSelector(selection: $first)
            SpaceSelector(selection: $second)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bifazPaper)
    }
}
