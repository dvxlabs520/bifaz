import SwiftUI
import BifazModels
import BifazDesign

/// Where the month's money went: one row per category, largest first, with a bar
/// in the space colour (relative to the largest share). Categories are told apart
/// by name and icon, never by colour.
struct CategoryBreakdownView: View {
    let shares: [CategoryShare]
    let categories: [UUID: ExpenseCategory]
    let tint: Color
    let onSelect: (UUID?) -> Void

    @State private var showAll = false

    private static let visibleCount = 6

    init(shares: [CategoryShare], categories: [UUID: ExpenseCategory], tint: Color, onSelect: @escaping (UUID?) -> Void) {
        self.shares = shares
        self.categories = categories
        self.tint = tint
        self.onSelect = onSelect
    }

    var body: some View {
        if !shares.isEmpty {
            VStack(alignment: .leading, spacing: BifazSpacing.m) {
                CategoryShareList(shares: Array(shares.prefix(Self.visibleCount)), categories: categories, tint: tint, onSelect: onSelect)
                if shares.count > Self.visibleCount {
                    Button {
                        showAll = true
                    } label: {
                        HStack(spacing: BifazSpacing.xxs) {
                            Text("summary.categories.seeAll", tableName: "Summary")
                            BifazIconView(.chevronRight, size: 14, relativeTo: .body)
                        }
                        .font(.bifazHeadline)
                        .foregroundStyle(Color.bifazInk)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ui.categoriesSeeAll")
                }
            }
            .sheet(isPresented: $showAll) {
                NavigationStack {
                    ScrollView {
                        CategoryShareList(shares: shares, categories: categories, tint: tint) { id in
                            showAll = false
                            onSelect(id)
                        }
                        .padding(BifazSpacing.screen)
                    }
                    .background(Color.bifazPaper)
                    .navigationTitle(Text("summary.categories.title", tableName: "Summary"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showAll = false
                            } label: {
                                BifazIconView(.close)
                            }
                            .accessibilityLabel(Text("summary.categories.close", tableName: "Summary"))
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryShareList: View {
    let shares: [CategoryShare]
    let categories: [UUID: ExpenseCategory]
    let tint: Color
    let onSelect: (UUID?) -> Void

    var body: some View {
        let largest = shares.map(\.amount).max() ?? 0
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            ForEach(shares) { share in
                let category = share.categoryID.flatMap { categories[$0] }
                CategoryShareRow(
                    name: category?.displayName ?? String(localized: "summary.category.none", table: "Summary"),
                    icon: category?.icon ?? .other,
                    share: share,
                    relative: largest > 0 ? ((share.amount / largest) as NSDecimalNumber).doubleValue : 0,
                    tint: tint
                ) { onSelect(share.categoryID) }
            }
        }
    }
}

private struct CategoryShareRow: View {
    let name: String
    let icon: BifazIcon
    let share: CategoryShare
    /// Length of the bar, 0…1, relative to the largest share.
    let relative: Double
    let tint: Color
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale

    private var percentText: String {
        (share.fraction as NSDecimalNumber).doubleValue
            .formatted(.percent.precision(.fractionLength(0...1)).locale(locale))
    }

    private var amountText: String {
        share.amount.formatted(.currency(code: "EUR").locale(locale))
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: BifazSpacing.s) {
                CategoryIcon(icon: icon, tint: tint, background: .bifazSurfaceMuted)
                VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
                    if typeSize.isAccessibilitySize {
                        Text(verbatim: name).font(.bifazBody).foregroundStyle(Color.bifazInk)
                        figures
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
                            Text(verbatim: name)
                                .font(.bifazBody)
                                .foregroundStyle(Color.bifazInk)
                            Spacer(minLength: BifazSpacing.xs)
                            figures
                        }
                    }
                    bar
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(name), \(amountText), \(percentText)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("ui.categoryShare")
    }

    private var figures: some View {
        HStack(spacing: BifazSpacing.xs) {
            Text(verbatim: amountText)
                .font(.bifazAmount)
                .foregroundStyle(Color.bifazInk)
            Text(verbatim: percentText)
                .font(.bifazCaption.monospacedDigit())
                .foregroundStyle(Color.bifazInkSecondary)
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bifazSurfaceMuted)
                Capsule().fill(tint)
                    .frame(width: max(6, proxy.size.width * min(max(relative, 0), 1)))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

private struct CategoryBreakdownPreviewHost: View {
    let count: Int
    var body: some View {
        ScrollView {
            CategoryBreakdownView(
                shares: Array(SummaryPreviewData.summary().categories.prefix(count)),
                categories: SummaryPreviewData.categoriesByID, tint: .bifazInk
            ) { _ in }
                .padding(BifazSpacing.screen)
        }
        .background(Color.bifazPaper)
    }
}

#Preview("Light") { CategoryBreakdownPreviewHost(count: 20) }
#Preview("Dark") { CategoryBreakdownPreviewHost(count: 20).preferredColorScheme(.dark) }
#Preview("Large text") { CategoryBreakdownPreviewHost(count: 20).dynamicTypeSize(.accessibility3) }
#Preview("Few") { CategoryBreakdownPreviewHost(count: 3) }
