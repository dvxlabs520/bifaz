import SwiftUI

/// Shared look of `FilterChip` and `CategoryChip`: an outlined capsule that
/// turns ink-filled when selected. Not interactive by itself (also used as the
/// label of a `Menu`, e.g. the client and project pickers).
public struct ChipLabel: View {
    let title: Text
    let icon: BifazIcon?
    let symbolTint: Color?
    let isSelected: Bool

    @ScaledMetric private var minHeight: CGFloat = 36

    public init(title: Text, icon: BifazIcon? = nil, symbolTint: Color? = nil, isSelected: Bool) {
        self.title = title
        self.icon = icon
        self.symbolTint = symbolTint
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: BifazSpacing.xs) {
            if let icon {
                BifazIconView(icon, size: 16, relativeTo: .subheadline)
                    .foregroundStyle(isSelected ? Color.bifazPaper : symbolTint ?? .bifazInk)
            }
            title
                .foregroundStyle(isSelected ? Color.bifazPaper : .bifazInk)
        }
        .font(.bifazSubheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, BifazSpacing.xxs)
        .frame(minHeight: minHeight)
        .background {
            if isSelected {
                Capsule().fill(Color.bifazInk)
            }
        }
        .overlay {
            if !isSelected {
                Capsule().strokeBorder(Color.bifazInkSecondary.opacity(0.35), lineWidth: 1)
            }
        }
        .contentShape(Capsule())
    }
}
