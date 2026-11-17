import SwiftUI
import BifazDesign

/// Shown instead of the app when the database cannot be opened.
struct StoreErrorView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            EmptyStateView(title: "storeError.title", message: "storeError.message")
            Spacer()
        }
        .padding(BifazSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.bifazPaper)
    }
}

#Preview {
    StoreErrorView()
}
