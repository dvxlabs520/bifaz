import SwiftUI
import BifazModels
import BifazDesign

/// Summary tab. Phase 0: space filter, the month's (empty) total and the
/// first-launch state. Real totals arrive in phases 1 and 3.
struct SummaryView: View {
    @Binding var spaceFilter: SpaceFilter

    /// "November" / "noviembre" / "novembre", as used inside a sentence.
    private var monthName: String {
        Date.now.formatted(Date.FormatStyle(capitalizationContext: .middleOfSentence).month(.wide))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SpaceSelector(selection: $spaceFilter)
                        .padding(.bottom, BifazSpacing.xl)

                    Text("summary.spentIn \(monthName)")
                        .font(.bifazCaption)
                        .foregroundStyle(.bifazInkSecondary)
                    AmountView(0, style: .hero, tint: .bifazInkSecondary)
                        .padding(.top, BifazSpacing.xxs)
                    SpaceSplitBar(pro: 0, personal: 0)
                        .padding(.top, BifazSpacing.s)

                    EmptyStateView(
                        title: "summary.empty.title",
                        message: "summary.empty.message",
                        primaryAction: .init("action.addExpense") {},
                        secondaryAction: .init("action.scanInvoice") {}
                    )
                    .padding(.top, BifazSpacing.xxl)
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.bottom, BifazSpacing.xxxl * 2)
            }
            .navigationTitle("tab.summary")
            .bifazScreen()
        }
    }
}

#Preview("Light") {
    SummaryView(spaceFilter: .constant(.all))
}

#Preview("Dark") {
    SummaryView(spaceFilter: .constant(.pro))
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    SummaryView(spaceFilter: .constant(.personal))
        .dynamicTypeSize(.accessibility3)
}
