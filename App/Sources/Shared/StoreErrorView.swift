import SwiftUI
import BifazDesign

/// Shown when the database cannot be opened: what happened, a retry, and a
/// code the user can quote to support.
struct StoreErrorView: View {
    let code: String
    let retry: @MainActor @Sendable () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.m) {
            Spacer()
            EmptyStateView(
                title: "storeError.title",
                message: "storeError.message",
                primaryAction: .init("storeError.retry", perform: retry)
            )
            Text("storeError.code \(code)")
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(BifazSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.bifazPaper)
    }
}

#Preview {
    StoreErrorView(code: "NSCocoaErrorDomain 134110") {}
}
