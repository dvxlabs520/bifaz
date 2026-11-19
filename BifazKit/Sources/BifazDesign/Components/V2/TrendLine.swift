import SwiftUI

/// A thin sparkline scaled to its frame: a 1.5 pt polyline from 0 to the
/// maximum, with a small dot on the last point. Fewer than two points draw a flat
/// hairline. Decorative (hidden from accessibility).
public struct TrendLine: View {
    private let points: [Decimal]
    private let tint: Color
    private let lineWidth: CGFloat = 1.5
    private let dot: CGFloat = 5

    public init(points: [Decimal], tint: Color = .bifazInk) {
        self.points = points
        self.tint = tint
    }

    /// Values scaled to 0…1 against a baseline of 0 (the largest value is 1).
    /// All values equal or all zero, or negative maxima, give a flat 0 line.
    /// Negative values clamp to 0.
    public nonisolated static func normalized(_ points: [Decimal]) -> [CGFloat] {
        guard let maximum = points.max(), maximum > 0 else {
            return points.map { _ in 0 }
        }
        return points.map { value in
            let ratio = max(value, 0) / maximum
            return CGFloat(NSDecimalNumber(decimal: ratio).doubleValue)
        }
    }

    public var body: some View {
        Canvas { context, size in
            guard points.count >= 2 else {
                var flat = Path()
                flat.move(to: CGPoint(x: 0, y: size.height - lineWidth / 2))
                flat.addLine(to: CGPoint(x: size.width, y: size.height - lineWidth / 2))
                context.stroke(flat, with: .color(.bifazHairline), lineWidth: 1)
                return
            }
            let values = Self.normalized(points)
            let inset = dot / 2
            let width = max(size.width - 2 * inset, 0)
            let height = max(size.height - 2 * inset, 0)
            let step = width / CGFloat(values.count - 1)
            let coordinates = values.enumerated().map { index, value in
                CGPoint(x: inset + step * CGFloat(index), y: inset + height * (1 - value))
            }
            var path = Path()
            path.addLines(coordinates)
            context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            if let last = coordinates.last {
                let rect = CGRect(x: last.x - dot / 2, y: last.y - dot / 2, width: dot, height: dot)
                context.fill(Path(ellipseIn: rect), with: .color(tint))
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Light") {
    TrendLineSamples()
}

#Preview("Dark") {
    TrendLineSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    TrendLineSamples().dynamicTypeSize(.accessibility3)
}

private struct TrendLineSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.l) {
            TrendLine(points: [12, 30, 28, 55, 80, 96, 140]).frame(width: 96, height: 36)
            TrendLine(points: [40, 10, 70, 20], tint: .bifazPro).frame(width: 96, height: 36)
            TrendLine(points: [5]).frame(width: 96, height: 36)
            TrendLine(points: []).frame(width: 96, height: 36)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
