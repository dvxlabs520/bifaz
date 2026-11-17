import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Every recurring expense, grouped Active / Paused / Ended, with the way to
/// add, edit, pause and delete them. Pushed inside an existing NavigationStack.
struct RecurringRulesView: View {
    private enum EditorTarget: Identifiable {
        case new
        case edit(RecurringRule)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let rule): rule.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringRule.nextDate) private var rules: [RecurringRule]
    @State private var editor: EditorTarget?
    @State private var pendingDeletion: RecurringRule?
    @State private var saveFailed = false
    @State private var changes = 0

    private var ended: [RecurringRule] { rules.filter { RecurringService.hasEnded($0) } }
    private var paused: [RecurringRule] { rules.filter { !RecurringService.hasEnded($0) && !$0.isActive } }
    private var active: [RecurringRule] { rules.filter { !RecurringService.hasEnded($0) && $0.isActive } }

    /// Monthly equivalent of the active rules of one space.
    private func monthlyTotal(in space: Space) -> Decimal {
        active.filter { $0.space == space }.reduce(Decimal(0)) { $0 + RecurringService.monthlyEquivalent(of: $1) }
    }

    var body: some View {
        Group {
            if rules.isEmpty {
                ScrollView { emptyState }
            } else {
                list
            }
        }
        .background(Color.bifazPaper)
        .navigationTitle(Text("recurring.title", tableName: "Recurring"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { target in
            switch target {
            case .new: RecurringRuleEditorView()
            case .edit(let rule): RecurringRuleEditorView(rule: rule)
            }
        }
        .confirmationDialog(
            Text("recurring.delete.title", tableName: "Recurring"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { rule in
            Button(role: .destructive) {
                delete(rule)
            } label: {
                Text("recurring.delete.action", tableName: "Recurring")
            }
        } message: { _ in
            Text("recurring.delete.message", tableName: "Recurring")
        }
        .alert(Text("recurring.error.title", tableName: "Recurring"), isPresented: $saveFailed) {
            Button {} label: { Text("recurring.error.ok", tableName: "Recurring") }
        }
        .sensoryFeedback(.selection, trigger: changes)
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            Text("recurring.empty.title", tableName: "Recurring")
                .font(.bifazTitle)
                .foregroundStyle(Color.bifazInk)
                .accessibilityAddTraits(.isHeader)
            Text("recurring.empty.message", tableName: "Recurring")
                .font(.bifazBody)
                .foregroundStyle(Color.bifazInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            addButton
                .padding(.top, BifazSpacing.xs)
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BifazSpacing.screen)
        .padding(.top, BifazSpacing.xl)
    }

    // MARK: List

    private var list: some View {
        VStack(spacing: 0) {
            List {
                if !active.isEmpty {
                    Section { totals.listRowStyle() }
                }
                group("recurring.group.active", active)
                group("recurring.group.paused", paused)
                group("recurring.group.ended", ended)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            addButton
                .padding(.horizontal, BifazSpacing.screen)
                .padding(.vertical, BifazSpacing.s)
        }
    }

    @ViewBuilder
    private func group(_ title: LocalizedStringResource, _ rows: [RecurringRule]) -> some View {
        if !rows.isEmpty {
            Section {
                ForEach(rows) { rule in row(rule) }
            } header: {
                Text(title)
                    .font(.bifazSubheadline)
                    .foregroundStyle(Color.bifazInkSecondary)
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    /// Monthly equivalent of the active rules, per space when both have some.
    private var totals: some View {
        let personal = monthlyTotal(in: .personal)
        let pro = monthlyTotal(in: .pro)
        let both = active.contains { $0.space == .personal } && active.contains { $0.space == .pro }
        return VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            if both {
                totalLine(space: .personal, amount: personal)
                totalLine(space: .pro, amount: pro)
            } else {
                Text("recurring.total.title", tableName: "Recurring")
                    .font(.bifazCaption)
                    .foregroundStyle(Color.bifazInkSecondary)
                Text("recurring.total.perMonth \((personal + pro).formatted(.currency(code: "EUR")))", tableName: "Recurring")
                    .font(.bifazTitle.monospacedDigit())
                    .foregroundStyle(Color.bifazInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BifazSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ui.ruleTotal")
    }

    private func totalLine(space: Space, amount: Decimal) -> some View {
        HStack(spacing: BifazSpacing.xs) {
            BifazIconView(space.icon, size: 16, relativeTo: .subheadline)
                .foregroundStyle(space.color)
            Text(space.title)
                .font(.bifazSubheadline)
                .foregroundStyle(Color.bifazInkSecondary)
            Spacer(minLength: BifazSpacing.xs)
            Text("recurring.total.perMonth \(amount.formatted(.currency(code: "EUR")))", tableName: "Recurring")
                .font(.bifazHeadline.monospacedDigit())
                .foregroundStyle(Color.bifazInk)
        }
    }

    private func amountText(_ rule: RecurringRule) -> Text {
        let amount = rule.amount.formatted(.currency(code: "EUR"))
        return switch rule.frequency {
        case .weekly: Text("recurring.row.amount.weekly \(amount)", tableName: "Recurring")
        case .monthly: Text("recurring.row.amount.monthly \(amount)", tableName: "Recurring")
        case .quarterly: Text("recurring.row.amount.quarterly \(amount)", tableName: "Recurring")
        case .yearly: Text("recurring.row.amount.yearly \(amount)", tableName: "Recurring")
        }
    }

    private func title(_ rule: RecurringRule) -> Text {
        if !rule.merchant.isEmpty { return Text(verbatim: rule.merchant) }
        if let name = rule.category?.displayName, !name.isEmpty { return Text(verbatim: name) }
        return Text("recurring.row.untitled", tableName: "Recurring")
    }

    private func row(_ rule: RecurringRule) -> some View {
        let space = rule.space
        return Button {
            editor = .edit(rule)
        } label: {
            HStack(spacing: BifazSpacing.m) {
                CategoryIcon(icon: rule.category?.icon ?? .other, tint: space.color, background: space.tint)
                VStack(alignment: .leading, spacing: 0) {
                    title(rule)
                        .font(.bifazBody)
                        .foregroundStyle(Color.bifazInk)
                    amountText(rule)
                        .font(.bifazCaption.monospacedDigit())
                        .foregroundStyle(Color.bifazInkSecondary)
                    if RecurringService.hasEnded(rule) {
                        Text("recurring.row.ended", tableName: "Recurring")
                            .font(.bifazCaption)
                            .foregroundStyle(Color.bifazInkSecondary)
                    } else if rule.isActive {
                        Text("recurring.row.next \(rule.nextDate.formatted(.dateTime.day().month(.abbreviated)))", tableName: "Recurring")
                            .font(.bifazCaption)
                            .foregroundStyle(Color.bifazInkSecondary)
                    }
                    if rule.frequency != .monthly {
                        let equivalent = RecurringService.monthlyEquivalent(of: rule).formatted(.currency(code: "EUR"))
                        Text("recurring.row.equivalent \(equivalent)", tableName: "Recurring")
                            .font(.bifazCaption.monospacedDigit())
                            .foregroundStyle(Color.bifazInkSecondary)
                    }
                }
                Spacer(minLength: BifazSpacing.xs)
                BifazIconView(.chevronRight, size: 14, relativeTo: .body)
                    .foregroundStyle(Color.bifazInkSecondary)
            }
            .padding(.vertical, BifazSpacing.xs)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("recurring.row.hint", tableName: "Recurring"))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ui.ruleRow")
        .listRowStyle()
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeletion = rule
            } label: {
                Text("recurring.delete.action", tableName: "Recurring")
            }
            if !RecurringService.hasEnded(rule) {
                Button {
                    setPaused(rule, rule.isActive)
                } label: {
                    rule.isActive
                        ? Text("recurring.swipe.pause", tableName: "Recurring")
                        : Text("recurring.swipe.resume", tableName: "Recurring")
                }
                .tint(Color.bifazInkSecondary)
            }
        }
    }

    private var addButton: some View {
        Button {
            editor = .new
        } label: {
            Text("recurring.add", tableName: "Recurring")
        }
        .buttonStyle(.bifazPrimary)
        .accessibilityIdentifier("ui.ruleAdd")
    }

    // MARK: Actions

    private func setPaused(_ rule: RecurringRule, _ paused: Bool) {
        do {
            try RecurringService.setPaused(rule, paused, in: modelContext)
            changes += 1
        } catch {
            Log.app.error("Pausing recurring rule failed: \(String(describing: error), privacy: .public)")
            modelContext.rollback()
            saveFailed = true
        }
    }

    private func delete(_ rule: RecurringRule) {
        do {
            try RecurringService.delete(rule, in: modelContext)
            changes += 1
        } catch {
            Log.app.error("Deleting recurring rule failed: \(String(describing: error), privacy: .public)")
            modelContext.rollback()
            saveFailed = true
        }
    }
}

private extension View {
    func listRowStyle() -> some View {
        self
            .listRowBackground(Color.bifazPaper)
            .listRowSeparatorTint(.bifazHairline)
            .listRowInsets(EdgeInsets(
                top: BifazSpacing.xxs, leading: BifazSpacing.screen,
                bottom: BifazSpacing.xxs, trailing: BifazSpacing.screen
            ))
    }
}

// MARK: - Previews

private enum RecurringRulesPreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            try CategorySeeder.seedIfNeeded(in: context)
            let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            func template(_ amount: Decimal, _ merchant: String, _ space: Space, _ frequency: RecurrenceFrequency,
                          start: Date, end: Date? = nil) -> RecurringService.Template {
                let category = categories.first { $0.space == space }
                return .init(
                    draft: ExpenseDraft(amount: amount, merchant: merchant, space: space, category: category),
                    frequency: frequency, startDate: start, endDate: end
                )
            }
            try RecurringService.create(template(71.99, "Freebox", .personal, .monthly, start: today), in: context)
            try RecurringService.create(template(287.88, "Assurance habitation", .personal, .yearly, start: today), in: context)
            try RecurringService.create(template(29, "Coworking", .pro, .weekly, start: today), in: context)
            let paused = try RecurringService.create(template(12.99, "Netflix", .personal, .monthly, start: today), in: context)
            try RecurringService.setPaused(paused, true, in: context)
            let old = calendar.date(byAdding: .month, value: -6, to: today) ?? today
            let past = calendar.date(byAdding: .month, value: -2, to: today)
            try RecurringService.create(template(9.99, "Old gym", .personal, .monthly, start: old, end: past), in: context)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}

#Preview("Light") {
    NavigationStack { RecurringRulesView() }
        .modelContainer(RecurringRulesPreviewData.container)
}

#Preview("Dark") {
    NavigationStack { RecurringRulesView() }
        .modelContainer(RecurringRulesPreviewData.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    NavigationStack { RecurringRulesView() }
        .modelContainer(RecurringRulesPreviewData.container)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Empty") {
    NavigationStack { RecurringRulesView() }
        .modelContainer(PreviewContainer.empty)
}
