import SwiftUI

/// An empty state without illustration: a title, an explanation and up to two
/// actions (primary, then secondary), leading aligned and capped in width so it
/// also reads well on wide screens.
public struct EmptyStateView: View {
    /// A button shown under the message.
    public struct Action: Sendable {
        let title: LocalizedStringResource
        let perform: @MainActor () -> Void

        public init(_ title: LocalizedStringResource, perform: @escaping @MainActor () -> Void) {
            self.title = title
            self.perform = perform
        }
    }

    private let title: LocalizedStringResource
    private let message: LocalizedStringResource
    private let primaryAction: Action?
    private let secondaryAction: Action?

    public init(
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        primaryAction: Action? = nil,
        secondaryAction: Action? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            Text(title)
                .font(.bifazTitle)
                .foregroundStyle(Color.bifazInk)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if primaryAction != nil || secondaryAction != nil {
                VStack(spacing: BifazSpacing.xs) {
                    if let primaryAction {
                        Button { primaryAction.perform() } label: { Text(primaryAction.title) }
                            .buttonStyle(.bifazPrimary)
                    }
                    if let secondaryAction {
                        Button { secondaryAction.perform() } label: { Text(secondaryAction.title) }
                            .buttonStyle(.bifazSecondary)
                    }
                }
                .padding(.top, BifazSpacing.xs)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            message: "Scanne un ticket de Monoprix ou ajoute une dépense à la main pour commencer.",
            primaryAction: .init("Scanner un justificatif") {},
            secondaryAction: .init("Ajouter à la main") {}
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
