import SwiftUI
import BifazModels
import BifazDesign

/// Summary tab. Phase 0: month header, an empty total and the welcome state.
struct SummaryView: View {
    @Binding var spaceFilter: SpaceFilter

    /// "November 2026", capitalised as a sentence in every language.
    private var monthTitle: String {
        Date.now.formatted(
            Date.FormatStyle(capitalizationContext: .beginningOfSentence).month(.wide).year()
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BifazSpacing.xl) {
                    SpaceSelector(selection: $spaceFilter)

                    VStack(alignment: .leading, spacing: BifazSpacing.s) {
                        Text(verbatim: monthTitle)
                            .font(.bifazTitle)
                            .foregroundStyle(.bifazInk)
                            .accessibilityAddTraits(.isHeader)
                        StatCard(
                            title: "summary.monthTotal",
                            amount: 0,
                            detail: "summary.monthTotal.empty",
                            accent: spaceFilter.color
                        )
                    }

                    EmptyStateView(
                        title: "summary.empty.title",
                        message: "summary.empty.message"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, BifazSpacing.m)
                }
                .padding(.horizontal, BifazSpacing.m)
                .padding(.bottom, BifazSpacing.xxxl * 2)
            }
            .background(Color.bifazPaper)
            .navigationTitle("tab.summary")
            .captureButtonOverlay()
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
