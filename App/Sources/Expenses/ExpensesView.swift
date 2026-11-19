import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Expenses tab: space selector, search, filters and the day-grouped history.
struct ExpensesView: View {
    @Binding var spaceFilter: SpaceFilter

    @State private var searchText = ""
    @State private var refinements = HistoryRefinements()
    @State private var isShowingFilters = false

    private var filter: ExpenseFilter {
        ExpenseFilter(
            space: spaceFilter,
            categoryIDs: refinements.categoryIDs,
            tagIDs: refinements.tagIDs,
            dateInterval: refinements.period.interval(),
            onlyReceiptPending: refinements.onlyReceiptPending,
            searchText: searchText
        )
    }

    var body: some View {
        let activeCount = filter.activeRefinementCount
        NavigationStack {
            VStack(spacing: 0) {
                SpaceSelector(selection: $spaceFilter)
                    .padding(.horizontal, BifazSpacing.screen)
                    .padding(.bottom, BifazSpacing.xs)
                ExpenseListView(filter: filter, onClearFilters: clearFilters)
            }
            .navigationTitle("tab.expenses")
            // v2 compact header: small centred title, search and filter in the bar.
            .navigationBarTitleDisplayMode(.inline)
            // Declared at the root of the stack: the Summary pushes this list too, with its own.
            .navigationDestination(for: PersistentIdentifier.self) { id in
                ExpenseDestination(id: id)
            }
            .searchable(
                text: $searchText,
                prompt: Text("history.search.prompt", tableName: "History")
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton(activeCount: activeCount)
                }
            }
            .sheet(isPresented: $isShowingFilters) {
                ExpenseFilterSheet(refinements: $refinements, spaceFilter: spaceFilter)
            }
            .onChange(of: spaceFilter) {
                // Category choices belong to a space: start clean when it changes.
                refinements.categoryIDs = []
                if spaceFilter == .personal { refinements.tagIDs = [] }
            }
            .bifazScreen()
        }
    }

    private func filterButton(activeCount: Int) -> some View {
        Button {
            isShowingFilters = true
        } label: {
            BifazIconView(.filter, size: 22)
                .foregroundStyle(Color.bifazInk)
                .overlay(alignment: .topTrailing) {
                    if activeCount > 0 {
                        Text(verbatim: activeCount.formatted())
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Color.bifazPaper)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(Color.bifazInk, in: Circle())
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .accessibilityLabel(
            activeCount > 0
                ? Text("history.filter.accessibility.active \(activeCount)", tableName: "History")
                : Text("history.filter.title", tableName: "History")
        )
    }

    private func clearFilters() {
        refinements = HistoryRefinements()
        searchText = ""
    }
}

#if DEBUG
private struct ExpensesPreview: View {
    let container = HistoryPreviewData.container()
    @State var spaceFilter: SpaceFilter
    @State private var navigation = AppNavigation()

    var body: some View {
        ExpensesView(spaceFilter: $spaceFilter)
            .modelContainer(container)
            .environment(navigation)
    }
}

#Preview("Light") {
    ExpensesPreview(spaceFilter: .all)
}

#Preview("Dark") {
    ExpensesPreview(spaceFilter: .pro)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    ExpensesPreview(spaceFilter: .personal)
        .dynamicTypeSize(.accessibility3)
}
#endif
