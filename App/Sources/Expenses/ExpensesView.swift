import SwiftUI
import BifazModels
import BifazDesign

/// Expenses tab. Phase 0: space filter and empty state; the history arrives in phase 1.
struct ExpensesView: View {
    @Binding var spaceFilter: SpaceFilter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SpaceSelector(selection: $spaceFilter)
                        .padding(.bottom, BifazSpacing.xxl)

                    EmptyStateView(
                        title: "expenses.empty.title",
                        message: "expenses.empty.message",
                        primaryAction: .init("action.addExpense") {}
                    )
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.bottom, BifazSpacing.xxxl * 2)
            }
            .navigationTitle("tab.expenses")
            .bifazScreen()
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
