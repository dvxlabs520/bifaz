import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Settings tab: brand header, organisation (categories), VAT switch and "About".
struct SettingsView: View {
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @AppStorage(ExchangeRateSetting.key) private var downloadsRates = ExchangeRateSetting.defaultValue
    @Query private var categories: [ExpenseCategory]
    @Query private var tags: [Tag]
    @Query private var rules: [RecurringRule]
    @Environment(\.modelContext) private var context
    @Environment(AppNavigation.self) private var navigation

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "\(short) (\(build))"
    }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.settingsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, BifazSpacing.xxl)

                    section("settings.section.organisation") {
                        NavigationLink {
                            CategoriesView()
                        } label: {
                            HStack(spacing: BifazSpacing.xs) {
                                Text("settings.categories", tableName: "Settings")
                                    .font(.bifazBody)
                                    .foregroundStyle(.bifazInk)
                                Spacer(minLength: BifazSpacing.xs)
                                Text(verbatim: categories.count.formatted())
                                    .font(.bifazBody)
                                    .monospacedDigit()
                                    .foregroundStyle(.bifazInkSecondary)
                                BifazIconView(.chevronRight, size: 14, relativeTo: .body)
                                    .foregroundStyle(.bifazInkSecondary)
                            }
                            .padding(.vertical, BifazSpacing.s)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        HairlineDivider()
                        navigationRow("settings.tags", count: tags.filter { !$0.isArchived }.count, identifier: "ui.settingsTags") {
                            TagsView()
                        }
                        HairlineDivider()
                        navigationRow("settings.recurring", count: rules.filter(\.isActive).count, identifier: "ui.settingsRecurring") {
                            RecurringRulesView()
                        }
                    }

                    section("settings.section.notifications") {
                        navigationRow("settings.notifications", count: nil, identifier: "ui.settingsNotifications") {
                            NotificationSettingsView {
                                Task { await NotificationScheduler.shared.reschedule(in: context) }
                            }
                        }
                    }

                    section("settings.section.rates") {
                        Toggle(isOn: $downloadsRates) {
                            Text("settings.rates.toggle", tableName: "Settings")
                                .font(.bifazBody)
                                .foregroundStyle(.bifazInk)
                        }
                        .tint(.bifazInk)
                        .padding(.vertical, BifazSpacing.xs)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("ui.settingsRates")
                    }
                    Text("settings.rates.caption", tableName: "Settings")
                        .font(.bifazCaption)
                        .foregroundStyle(.bifazInkSecondary)
                        .padding(.top, BifazSpacing.s)

                    section("settings.section.vat") {
                        Toggle(isOn: $isVATRegistered) {
                            Text("settings.vat.toggle", tableName: "Settings")
                                .font(.bifazBody)
                                .foregroundStyle(.bifazInk)
                        }
                        .tint(.bifazInk)
                        .padding(.vertical, BifazSpacing.xs)
                        .frame(minHeight: 44)
                    }
                    Text("settings.vat.caption", tableName: "Settings")
                        .font(.bifazCaption)
                        .foregroundStyle(.bifazInkSecondary)
                        .padding(.top, BifazSpacing.s)
                        .padding(.bottom, BifazSpacing.xxl)

                    section("settings.about", inDefaultTable: true) {
                        LabeledContent {
                            Text(verbatim: version)
                                .font(.bifazBody)
                                .monospacedDigit()
                                .foregroundStyle(.bifazInkSecondary)
                        } label: {
                            Text("settings.version")
                                .font(.bifazBody)
                                .foregroundStyle(.bifazInk)
                        }
                        .padding(.vertical, BifazSpacing.s)
                    }

                    Text("settings.footer")
                        .font(.bifazCaption)
                        .foregroundStyle(.bifazInkSecondary)
                        .padding(.top, BifazSpacing.s)
                }
                .padding(.horizontal, BifazSpacing.screen)
                .padding(.top, BifazSpacing.xs)
            }
            .navigationTitle("tab.settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .recurringRules: RecurringRulesView()
                case .recurringRule(let id): RecurringRuleDestination(id: id)
                }
            }
            .bifazScreen()
        }
    }

    private var header: some View {
        HStack(spacing: BifazSpacing.m) {
            BifazAppIcon(side: 64)
            VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
                Text(BrandStrings.name)
                    .font(.bifazTitle)
                    .foregroundStyle(.bifazInk)
                Text(BrandStrings.tagline)
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// A row that pushes a screen, with an optional count on the right.
    private func navigationRow<Destination: View>(
        _ title: String.LocalizationValue,
        count: Int?,
        identifier: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: BifazSpacing.xs) {
                Text(LocalizedStringResource(title, table: "Settings"))
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInk)
                Spacer(minLength: BifazSpacing.xs)
                if let count {
                    Text(verbatim: count.formatted())
                        .font(.bifazBody)
                        .monospacedDigit()
                        .foregroundStyle(.bifazInkSecondary)
                }
                BifazIconView(.chevronRight, size: 14, relativeTo: .body)
                    .foregroundStyle(.bifazInkSecondary)
            }
            .padding(.vertical, BifazSpacing.s)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    /// A titled group of rows framed by hairlines.
    private func section<Content: View>(
        _ title: String,
        inDefaultTable: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(
                inDefaultTable
                    ? LocalizedStringResource(String.LocalizationValue(title))
                    : LocalizedStringResource(String.LocalizationValue(title), table: "Settings")
            )
            .padding(.bottom, BifazSpacing.xs)
            HairlineDivider()
            content()
            HairlineDivider()
        }
        .padding(.top, BifazSpacing.xl)
    }
}

// MARK: - Previews

private enum SettingsPreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            let software = ExpenseCategory(name: "Logiciels", iconName: "software", space: .pro, sortOrder: 0)
            let meals = ExpenseCategory(name: "Repas", iconName: "meal", space: .pro, sortOrder: 1)
            let groceries = ExpenseCategory(name: "Courses", iconName: "groceries", space: .personal, sortOrder: 0)
            for category in [software, meals, groceries] { context.insert(category) }
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}

#Preview("Light") {
    SettingsView()
        .modelContainer(SettingsPreviewData.container)
        .environment(AppNavigation())
}

#Preview("Dark") {
    SettingsView()
        .modelContainer(SettingsPreviewData.container)
        .environment(AppNavigation())
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    SettingsView()
        .modelContainer(SettingsPreviewData.container)
        .environment(AppNavigation())
        .dynamicTypeSize(.accessibility3)
}

/// Places a notification can open inside Settings.
enum SettingsRoute: Hashable {
    case recurringRules
    case recurringRule(UUID)
}

/// Opens the editor of a rule by id (from a notification).
private struct RecurringRuleDestination: View {
    let id: UUID
    @Query private var rules: [RecurringRule]
    @State private var isEditing = true

    var body: some View {
        RecurringRulesView()
            .sheet(isPresented: $isEditing) {
                if let rule = rules.first(where: { $0.id == id }) { RecurringRuleEditorView(rule: rule) }
            }
    }
}
