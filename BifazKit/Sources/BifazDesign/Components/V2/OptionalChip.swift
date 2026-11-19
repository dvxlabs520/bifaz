import SwiftUI

/// An optional field of the entry form ("VAT", "Note", "Receipt"): an outlined
/// capsule with icon and title. Once it has a value it shows "title · value" in
/// ink on a muted fill. Reads as "VAT, 20 %" for VoiceOver.
public struct OptionalChip: View {
    @Environment(\.locale) private var locale
    @ScaledMetric private var minHeight: CGFloat = 36

    private let title: LocalizedStringResource
    private let icon: BifazIcon
    private let value: String?
    private let action: () -> Void

    public init(_ title: LocalizedStringResource, icon: BifazIcon, value: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.value = value.flatMap { $0.isEmpty ? nil : $0 }
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: BifazSpacing.xs) {
                BifazIconView(icon, size: 16, relativeTo: .subheadline)
                    .foregroundStyle(value == nil ? Color.bifazInkSecondary : .bifazInk)
                label
            }
            .font(.bifazSubheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, BifazSpacing.xxs)
            .frame(minHeight: minHeight)
            .background(value == nil ? Color.bifazSurface : .bifazSurfaceMuted, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.bifazHairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    @ViewBuilder
    private var label: some View {
        if let value {
            Text("\(Text(title)) · \(Text(verbatim: value))")
                .foregroundStyle(Color.bifazInk)
        } else {
            Text(title)
                .foregroundStyle(Color.bifazInkSecondary)
        }
    }

    private var accessibilityText: String {
        let name = title.resolved(in: locale)
        guard let value else { return name }
        return LocalizedStringResource("optionalChip.accessibility \(name) \(value)", bundle: .module).resolved(in: locale)
    }
}

#Preview("Light") {
    OptionalChipSamples()
}

#Preview("Dark") {
    OptionalChipSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    OptionalChipSamples().dynamicTypeSize(.accessibility3)
}

private struct OptionalChipSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            OptionalChip("budget.label", icon: .percent) {}
            OptionalChip("budget.label", icon: .percent, value: "20 %") {}
            OptionalChip("space.personal", icon: .note, value: "Déjeuner avec le client") {}
            OptionalChip("receipt.none", icon: .receipt) {}
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
