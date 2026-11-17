import SwiftUI
import BifazDesign

/// Shown instead of the app when the database cannot be opened.
struct StoreErrorView: View {
    var body: some View {
        EmptyStateView(
            title: "storeError.title",
            message: "storeError.message",
            illustration: .symbol("exclamationmark.triangle")
        )
        .padding(BifazSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bifazPaper)
    }
}

#Preview {
    StoreErrorView()
}
