import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Period choices of the history filter.
enum HistoryPeriod: CaseIterable, Identifiable {
    case allTime, thisMonth, lastMonth, thisQuarter, thisYear

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .allTime: LocalizedStringResource("history.period.all", table: "History")
        case .thisMonth: LocalizedStringResource("history.period.thisMonth", table: "History")
        case .lastMonth: LocalizedStringResource("history.period.lastMonth", table: "History")
        case .thisQuarter: LocalizedStringResource("history.period.thisQuarter", table: "History")
        case .thisYear: LocalizedStringResource("history.period.thisYear", table: "History")
        }
    }

    /// The date range, or `nil` for all time.
    func interval(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .allTime:
            return nil
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            guard let previous = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
            return calendar.dateInterval(of: .month, for: previous)
        case .thisQuarter:
            return calendar.dateInterval(of: .quarter, for: now)
        case .thisYear:
            return calendar.dateInterval(of: .year, for: now)
        }
    }
}

/// The filter choices made in the sheet (space and search live outside it).
struct HistoryRefinements: Equatable {
    var period: HistoryPeriod = .allTime
    var categoryIDs: Set<UUID> = []
    var onlyReceiptPending = false

    var isDefault: Bool { self == HistoryRefinements() }
}

/// Qonto-style filter sheet: period, categories and receipt state.
struct ExpenseFilterSheet: View {
    @Binding var refinements: HistoryRefinements
    let spaceFilter: SpaceFilter

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BifazSpacing.xl) {
                    periodSection
                    categoriesSection
                    receiptSection
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.top, BifazSpacing.xs)
                .padding(.bottom, BifazSpacing.l)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.bifazPaper)
            .navigationTitle(Text("history.filter.title", tableName: "History"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        BifazIconView(.close, size: 18)
                    }
                    .accessibilityLabel(Text("history.filter.close", tableName: "History"))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.bifazPaper)
    }

    // MARK: Sections

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            SectionHeader(LocalizedStringResource("history.period.title", table: "History"))
            FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
                ForEach(HistoryPeriod.allCases) { period in
                    FilterChip(period.title, isSelected: refinements.period == period) {
                        refinements.period = period
                    }
                }
            }
        }
    }

    private var visibleSpaces: [Space] {
        [Space.pro, .personal].filter { spaceFilter.includes($0) }
    }

    @ViewBuilder
    private var categoriesSection: some View {
        let spaces = visibleSpaces.filter { space in categories.contains { $0.space == space } }
        if !spaces.isEmpty {
            VStack(alignment: .leading, spacing: BifazSpacing.s) {
                SectionHeader(LocalizedStringResource("history.categories.title", table: "History"))
                ForEach(spaces) { space in
                    VStack(alignment: .leading, spacing: BifazSpacing.xs) {
                        if spaceFilter == .all {
                            Text(space.title)
                                .font(.bifazCaption)
                                .foregroundStyle(Color.bifazInkSecondary)
                        }
                        FlowLayout(spacing: BifazSpacing.xs, lineSpacing: BifazSpacing.xs) {
                            ForEach(categories.filter { $0.space == space }) { category in
                                categoryChip(category, space: space)
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryChip(_ category: ExpenseCategory, space: Space) -> some View {
        let isSelected = refinements.categoryIDs.contains(category.id)
        return Button {
            if isSelected {
                refinements.categoryIDs.remove(category.id)
            } else {
                refinements.categoryIDs.insert(category.id)
            }
        } label: {
            CategoryChip(category.name, icon: category.icon, tint: space.color, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            SectionHeader(LocalizedStringResource("history.receipt.title", table: "History"))
            Toggle(isOn: $refinements.onlyReceiptPending) {
                Text("history.receipt.onlyMissing", tableName: "History")
                    .font(.bifazBody)
                    .foregroundStyle(Color.bifazInk)
            }
            .tint(.bifazInk)
            .padding(.vertical, BifazSpacing.xs)
        }
    }

    private var actions: some View {
        VStack(spacing: BifazSpacing.xs) {
            Button {
                dismiss()
            } label: {
                Text("history.filter.show", tableName: "History")
            }
            .buttonStyle(.bifazPrimary)
            Button {
                refinements = HistoryRefinements()
            } label: {
                Text("history.filter.reset", tableName: "History")
            }
            .buttonStyle(.bifazSecondary)
            .disabled(refinements.isDefault)
        }
        .padding(.horizontal, BifazSpacing.l)
        .padding(.vertical, BifazSpacing.s)
        .background(Color.bifazPaper)
    }
}

#if DEBUG
private struct FilterSheetPreview: View {
    @State private var refinements = HistoryRefinements(period: .thisMonth)
    let container: ModelContainer

    init() {
        container = HistoryPreviewData.container()
    }

    var body: some View {
        ExpenseFilterSheet(refinements: $refinements, spaceFilter: .all)
            .modelContainer(container)
    }
}

#Preview("Light") {
    FilterSheetPreview()
}

#Preview("Dark") {
    FilterSheetPreview().preferredColorScheme(.dark)
}

#Preview("Large text") {
    FilterSheetPreview().dynamicTypeSize(.accessibility3)
}
#endif
