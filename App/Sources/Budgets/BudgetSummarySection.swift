import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// How a budget state looks and reads: colour, icon and word, always together.
extension BudgetState {
    var budgetColor: Color {
        switch self {
        case .normal: .bifazSuccess
        case .nearLimit: .bifazWarning
        case .over: .bifazError
        }
    }

    var budgetIcon: BifazIcon {
        switch self {
        case .normal: .check
        case .nearLimit: .warning
        case .over: .close
        }
    }

    var budgetWord: LocalizedStringResource {
        switch self {
        case .normal: LocalizedStringResource("budgets.state.normal", table: "Budgets")
        case .nearLimit: LocalizedStringResource("budgets.state.nearLimit", table: "Budgets")
        case .over: LocalizedStringResource("budgets.state.over", table: "Budgets")
        }
    }
}

extension Decimal {
    /// "120,00 €" in `locale`.
    func budgetCurrency(in locale: Locale) -> String {
        formatted(.currency(code: "EUR").locale(locale))
    }
}

extension LocalizedStringResource {
    /// The resource resolved to a `String` in `locale` (for accessibility texts).
    func budgetResolved(in locale: Locale) -> String {
        var resource = self
        resource.locale = locale
        return String(localized: resource)
    }
}

/// The "Budgets" block of the Summary tab: one bar per budget, with what is left
/// (current month) or how the month ended (past month). The parent provides the
/// 16 pt margins and the spacing above.
struct BudgetSummarySection: View {
    @Environment(\.locale) private var locale
    @State private var creating = false

    private let statuses: [BudgetStatus]
    private let categories: [UUID: ExpenseCategory]
    private let isCurrentMonth: Bool

    init(statuses: [BudgetStatus], categories: [UUID: ExpenseCategory], isCurrentMonth: Bool) {
        self.statuses = statuses
        self.categories = categories
        self.isCurrentMonth = isCurrentMonth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.m) {
            header
            if statuses.isEmpty {
                invitation
            } else {
                ForEach(statuses) { status in
                    block(status)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $creating) {
            BudgetEditorView()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
            SectionHeader(LocalizedStringResource("budgets.title", table: "Budgets"))
            if !statuses.isEmpty {
                NavigationLink {
                    BudgetsView()
                } label: {
                    Text("budgets.summary.manage", tableName: "Budgets")
                        .font(.bifazCaption)
                        .foregroundStyle(Color.bifazInkSecondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("ui.budgetsManage")
            }
        }
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            Text("budgets.summary.invite", tableName: "Budgets")
                .font(.bifazCaption)
                .foregroundStyle(Color.bifazInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                creating = true
            } label: {
                Text("budgets.summary.create", tableName: "Budgets")
            }
            .buttonStyle(.bifazSecondary)
            .accessibilityIdentifier("ui.budgetCreateFirst")
        }
    }

    private func block(_ status: BudgetStatus) -> some View {
        let category = categories[status.categoryID]
        let name = category?.displayName ?? ""
        return VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            HStack(spacing: BifazSpacing.s) {
                CategoryIcon(
                    icon: category?.icon ?? .other,
                    tint: status.space.color,
                    background: status.space.tint,
                    side: 32
                )
                Text(verbatim: name)
                    .font(.bifazHeadline)
                    .foregroundStyle(Color.bifazInk)
                Spacer(minLength: 0)
            }
            BudgetBar(status: status)
            if let detail = detail(status) {
                detail
                    .font(.bifazCaption.monospacedDigit())
                    .foregroundStyle(Color.bifazInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(verbatim: accessibilityValue(status)))
        .accessibilityIdentifier("ui.budgetStatus")
    }

    /// What is left (current month) or the result (past month).
    private func detail(_ status: BudgetStatus) -> Text? {
        let remaining = status.remaining
        if isCurrentMonth, let days = status.daysLeft {
            if remaining > 0 {
                let amount = remaining.budgetCurrency(in: locale)
                return days == 1
                    ? Text("budgets.summary.left.day \(amount)", tableName: "Budgets")
                    : Text("budgets.summary.left.days \(amount) \(days)", tableName: "Budgets")
            }
            return remaining < 0 ? overText(remaining) : nil
        }
        if remaining < 0 { return overText(remaining) }
        if remaining == 0 { return Text("budgets.summary.kept", tableName: "Budgets") }
        let amount = remaining.budgetCurrency(in: locale)
        return Text("budgets.summary.unspent \(amount)", tableName: "Budgets")
    }

    private func overText(_ remaining: Decimal) -> Text {
        let amount = (-remaining).budgetCurrency(in: locale)
        return Text("budgets.summary.over \(amount)", tableName: "Budgets")
    }

    /// State word, spent of limit, then the detail line.
    private func accessibilityValue(_ status: BudgetStatus) -> String {
        let spent = status.spent.budgetCurrency(in: locale)
        let limit = status.limit.budgetCurrency(in: locale)
        let progress = LocalizedStringResource("budgets.summary.progress \(spent) \(limit)", table: "Budgets")
        var parts = [
            status.state.budgetWord.budgetResolved(in: locale),
            progress.budgetResolved(in: locale),
        ]
        if let detail = accessibilityDetail(status) { parts.append(detail) }
        return parts.joined(separator: ". ")
    }

    private func accessibilityDetail(_ status: BudgetStatus) -> String? {
        let remaining = status.remaining
        let amount = abs(remaining).budgetCurrency(in: locale)
        let resource: LocalizedStringResource
        if remaining < 0 {
            resource = LocalizedStringResource("budgets.summary.over \(amount)", table: "Budgets")
        } else if isCurrentMonth, let days = status.daysLeft {
            guard remaining > 0 else { return nil }
            resource = days == 1
                ? LocalizedStringResource("budgets.summary.left.day \(amount)", table: "Budgets")
                : LocalizedStringResource("budgets.summary.left.days \(amount) \(days)", table: "Budgets")
        } else if remaining == 0 {
            resource = LocalizedStringResource("budgets.summary.kept", table: "Budgets")
        } else {
            resource = LocalizedStringResource("budgets.summary.unspent \(amount)", table: "Budgets")
        }
        return resource.budgetResolved(in: locale)
    }
}

// MARK: - Previews

/// Statuses computed by the model from an in-memory store, for previews.
@MainActor
enum BudgetPreviewData {
    struct Samples {
        var container: ModelContainer
        var current: [BudgetStatus]
        var past: [BudgetStatus]
        var categories: [UUID: ExpenseCategory]
    }

    static let samples: Samples = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            try SampleData.insert(into: context)
            let all = try context.fetch(FetchDescriptor<ExpenseCategory>())
            func category(_ key: String) -> ExpenseCategory? { all.first { $0.seedKey == key } }
            let picks: [(String, Decimal)] = [
                ("category.pro.software", 70),
                ("category.pro.transport", 100),
                ("category.personal.groceries", 400),
            ]
            var chosen: [ExpenseCategory] = []
            for (key, limit) in picks {
                guard let category = category(key) else { continue }
                try BudgetService.setBudget(limit, for: category, in: context)
                chosen.append(category)
            }
            let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
            return Samples(
                container: container,
                current: try chosen.compactMap { try BudgetService.status(of: $0, at: .now, in: context) },
                past: try chosen.compactMap { try BudgetService.status(of: $0, at: lastMonth, in: context) },
                categories: Dictionary(uniqueKeysWithValues: chosen.map { ($0.id, $0) })
            )
        } catch {
            fatalError("Preview data failed: \(error)")
        }
    }()
}

private struct SummarySamples: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BifazSpacing.xl) {
                BudgetSummarySection(
                    statuses: BudgetPreviewData.samples.current,
                    categories: BudgetPreviewData.samples.categories,
                    isCurrentMonth: true
                )
                BudgetSummarySection(
                    statuses: BudgetPreviewData.samples.past,
                    categories: BudgetPreviewData.samples.categories,
                    isCurrentMonth: false
                )
                BudgetSummarySection(statuses: [], categories: [:], isCurrentMonth: true)
            }
            .padding(.horizontal, BifazSpacing.screen)
        }
        .background(Color.bifazPaper)
    }
}

#Preview("Light") {
    NavigationStack { SummarySamples() }
        .modelContainer(BudgetPreviewData.samples.container)
}

#Preview("Dark") {
    NavigationStack { SummarySamples() }
        .modelContainer(BudgetPreviewData.samples.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    NavigationStack { SummarySamples() }
        .modelContainer(BudgetPreviewData.samples.container)
        .dynamicTypeSize(.accessibility3)
}
