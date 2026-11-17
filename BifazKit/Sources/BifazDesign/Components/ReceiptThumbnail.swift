import SwiftUI

/// A small rounded thumbnail of a receipt. Shows the image when one is
/// attached, otherwise a symbol that tells the receipt state without relying
/// on colour alone.
public struct ReceiptThumbnail: View {
    /// Whether a receipt exists for the expense.
    public enum State: Sendable, Equatable {
        /// A receipt is attached.
        case attached
        /// A receipt is expected but still missing.
        case pending
        /// The expense has no receipt.
        case none
    }

    private let image: Image?
    private let state: State
    @ScaledMetric private var side: CGFloat

    public init(image: Image? = nil, state: State, side: CGFloat = 44) {
        self.image = image
        self.state = state
        _side = ScaledMetric(wrappedValue: side, relativeTo: .body)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous)
    }

    public var body: some View {
        content
            .frame(width: side, height: side)
            .background(Color.bifazSurface, in: shape)
            .clipShape(shape)
            .overlay(border)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityText))
    }

    @ViewBuilder
    private var content: some View {
        if state == .attached, let image {
            image
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: symbolName)
                .font(.bifazBody)
                .foregroundStyle(state == .pending ? Color.bifazWarning : state == .none ? Color.bifazInkSecondary : Color.bifazInk)
        }
    }

    @ViewBuilder
    private var border: some View {
        if state == .pending {
            shape.strokeBorder(Color.bifazWarning, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        } else {
            shape.strokeBorder(Color.bifazHairline, lineWidth: 1)
        }
    }

    private var symbolName: String {
        switch state {
        case .attached: "doc.text"
        case .pending: "doc.badge.clock"
        case .none: "doc"
        }
    }

    private var accessibilityText: LocalizedStringResource {
        switch state {
        case .attached: LocalizedStringResource("receipt.attached", bundle: .module)
        case .pending: LocalizedStringResource("receipt.pending", bundle: .module)
        case .none: LocalizedStringResource("receipt.none", bundle: .module)
        }
    }
}

#Preview("Light") {
    ReceiptThumbnailSamples()
}

#Preview("Dark") {
    ReceiptThumbnailSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    ReceiptThumbnailSamples().dynamicTypeSize(.accessibility3)
}

private struct ReceiptThumbnailSamples: View {
    var body: some View {
        HStack(spacing: BifazSpacing.m) {
            ReceiptThumbnail(image: Image(systemName: "photo"), state: .attached)
            ReceiptThumbnail(state: .attached)
            ReceiptThumbnail(state: .pending)
            ReceiptThumbnail(state: .none)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bifazPaper)
    }
}
