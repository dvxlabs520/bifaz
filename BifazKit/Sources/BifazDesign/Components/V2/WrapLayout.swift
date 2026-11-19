import SwiftUI

/// Marks a child that must join the previous one without a space (", en").
struct AttachesToPreviousKey: LayoutValueKey {
    static let defaultValue = false
}

/// Lays children out left to right and wraps them onto new lines, like words in
/// a paragraph. A child that sets `AttachesToPreviousKey` sits flush against the
/// one before it. Children wider than the line are proposed the line width.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    private struct Line {
        var items: [(index: Int, size: CGSize, gap: CGFloat)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var lines = [Line()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            let attaches = subviews[index][AttachesToPreviousKey.self]
            var line = lines[lines.count - 1]
            let gap = line.items.isEmpty || attaches ? 0 : spacing
            if !line.items.isEmpty, !attaches, line.width + gap + size.width > maxWidth {
                lines.append(Line())
                line = Line()
            }
            let lineGap = line.items.isEmpty ? 0 : gap
            line.items.append((index, size, lineGap))
            line.width += lineGap + size.width
            line.height = max(line.height, size.height)
            lines[lines.count - 1] = line
        }
        return lines.filter { !$0.items.isEmpty }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = arrange(maxWidth: maxWidth, subviews: subviews)
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
        let width = lines.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in line.items {
                x += item.gap
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (line.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width
            }
            y += line.height + lineSpacing
        }
    }
}
