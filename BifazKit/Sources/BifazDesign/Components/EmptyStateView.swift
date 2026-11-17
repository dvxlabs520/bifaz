import SwiftUI

/// A centred empty state: illustration, title, message and an optional
/// primary action. Content is capped at a readable width, so it also looks
/// right on iPad.
public struct EmptyStateView: View {
    /// The picture above the title.
    public enum Illustration: Sendable {
        /// The Bifaz coin.
        case coin
        /// An SF Symbol by name.
        case symbol(String)
    }

    @ScaledMetric private var illustrationSide: CGFloat = 88

    private let title: LocalizedStringResource
    private let message: LocalizedStringResource
    private let illustration: Illustration
    private let actionTitle: LocalizedStringResource?
    private let action: (@MainActor () -> Void)?

    public init(
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        illustration: Illustration = .coin,
        actionTitle: LocalizedStringResource? = nil,
        action: (@MainActor () -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.illustration = illustration
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: BifazSpacing.l) {
            illustrationView
            VStack(spacing: BifazSpacing.xs) {
                Text(title)
                    .font(.bifazTitle)
                    .foregroundStyle(Color.bifazInk)
                Text(message)
                    .font(.bifazBody)
                    .foregroundStyle(Color.bifazInkSecondary)
            }
            .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.bifazPrimary)
                .padding(.top, BifazSpacing.xs)
            }
        }
        .frame(maxWidth: 360)
        .padding(BifazSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var illustrationView: some View {
        switch illustration {
        case .coin:
            CoinMark()
                .frame(width: illustrationSide, height: illustrationSide)
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.bifazInkSecondary)
                .frame(width: illustrationSide * 0.6, height: illustrationSide * 0.6)
                .frame(width: illustrationSide, height: illustrationSide)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Light") {
    EmptyStateSamples()
}

#Preview("Dark") {
    EmptyStateSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    EmptyStateSamples().dynamicTypeSize(.accessibility3)
}

private struct EmptyStateSamples: View {
    var body: some View {
        EmptyStateView(
            title: "Aucune dépense",
            message: "Scannez un ticket de Monoprix ou de la SNCF pour commencer.",
            actionTitle: "Scanner un ticket",
            action: {}
        )
        .background(Color.bifazPaper)
    }
}
