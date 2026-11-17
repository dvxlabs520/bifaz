import SwiftUI
import BifazModels
import BifazDesign

/// Expenses tab. Phase 0: space selector and empty state.
struct ExpensesView: View {
    @Binding var spaceFilter: SpaceFilter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BifazSpacing.xxl) {
                    SpaceSelector(selection: $spaceFilter)

                    EmptyStateView(
                        title: "expenses.empty.title",
                        message: "expenses.empty.message",
                        illustration: .symbol("tray")
                    )
                    .padding(.top, BifazSpacing.xxl)
                }
                .padding(.horizontal, BifazSpacing.m)
                .padding(.bottom, BifazSpacing.xxxl * 2)
            }
            .background(Color.bifazPaper)
            .navigationTitle("tab.expenses")
            .captureButtonOverlay()
        }
    }
}

#Preview("Light") {
    ExpensesView(spaceFilter: .constant(.all))
}

#Preview("Dark") {
    ExpensesView(spaceFilter: .constant(.pro))
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    ExpensesView(spaceFilter: .constant(.personal))
        .dynamicTypeSize(.accessibility3)
}
