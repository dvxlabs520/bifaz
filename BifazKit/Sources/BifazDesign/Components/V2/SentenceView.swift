import SwiftUI

/// The entry sentence ("I spent 42,00 € at Monoprix on Courses · Personal · today")
/// written large and wrapping like text. Words are in secondary ink; each value
/// is a button in ink with a 2 pt underline (placeholders are lighter with a
/// dotted underline, the focused value gets a thicker ink underline).
public struct SentenceView: View {
    private let pieces: [SentencePiece]
    private let focused: SentencePiece.Role?
    private let onTap: (SentencePiece.Role) -> Void

    public init(pieces: [SentencePiece], focused: SentencePiece.Role? = nil, onTap: @escaping (SentencePiece.Role) -> Void) {
        self.pieces = pieces
        self.focused = focused
        self.onTap = onTap
    }

    /// One laid-out item: a single word, or a whole tappable piece.
    private struct Item: Identifiable {
        let id: String
        let piece: SentencePiece
        let text: String
        let attaches: Bool
    }

    private var items: [Item] {
        pieces.flatMap { piece -> [Item] in
            guard !piece.isTappable else {
                return [Item(id: "\(piece.index)", piece: piece, text: piece.text, attaches: false)]
            }
            let words = piece.text.split(separator: " ").map(String.init)
            return words.enumerated().map { offset, word in
                Item(id: "\(piece.index)-\(offset)", piece: piece, text: word, attaches: offset == 0 && piece.attachesToPrevious)
            }
        }
    }

    public var body: some View {
        WrapLayout(spacing: 6, lineSpacing: 6) {
            ForEach(items) { item in
                if item.piece.isTappable {
                    tappable(item.piece)
                } else {
                    Text(verbatim: item.text)
                        .font(.title2)
                        .foregroundStyle(Color.bifazInkSecondary)
                        .padding(.bottom, Self.underlineGap)
                        .layoutValue(key: AttachesToPreviousKey.self, value: item.attaches)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: ExpenseSentence.plainText(pieces)))
    }

    private static let underlineGap: CGFloat = 5

    private func tappable(_ piece: SentencePiece) -> some View {
        let isFocused = focused == piece.role
        return Button {
            onTap(piece.role)
        } label: {
            Text(verbatim: piece.text)
                .font(.system(.title2, weight: .medium))
                .foregroundStyle(piece.isPlaceholder ? Color.bifazInkSecondary : .bifazInk)
                .multilineTextAlignment(.leading)
                .padding(.bottom, Self.underlineGap)
                .overlay(alignment: .bottom) {
                    underline(placeholder: piece.isPlaceholder, focused: isFocused)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: piece.accessibilityLabel))
        .accessibilityIdentifier("ui.sentence.\(piece.role.rawValue)")
        .layoutValue(key: AttachesToPreviousKey.self, value: false)
    }

    @ViewBuilder
    private func underline(placeholder: Bool, focused: Bool) -> some View {
        let thickness: CGFloat = focused ? 3 : 2
        if placeholder && !focused {
            Line()
                .stroke(Color.bifazInkSecondary, style: StrokeStyle(lineWidth: thickness, lineCap: .round, dash: [0.1, 4]))
                .frame(height: thickness)
        } else {
            Capsule()
                .fill(focused || !placeholder ? Color.bifazInk : Color.bifazInkSecondary)
                .frame(height: thickness)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

#Preview("Light") {
    SentenceSamples()
}

#Preview("Dark") {
    SentenceSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    SentenceSamples().dynamicTypeSize(.accessibility3)
}

private struct SentenceSamples: View {
    private func pieces(_ input: ExpenseSentenceInput, _ id: String) -> [SentencePiece] {
        ExpenseSentence.pieces(input, locale: Locale(identifier: id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xl) {
            SentenceView(
                pieces: pieces(ExpenseSentenceInput(amount: 42.80, merchant: "Monoprix", categoryName: "Courses", space: .personal, date: .now), "fr_FR"),
                focused: .merchant
            ) { _ in }
            SentenceView(
                pieces: pieces(ExpenseSentenceInput(amount: nil, merchant: "", categoryName: nil, space: .pro, date: .now.addingTimeInterval(-86_400)), "es_ES")
            ) { _ in }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bifazPaper)
    }
}
