import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Settings tab: brand header, organisation (categories), VAT switch and "About".
struct SettingsView: View {
    @AppStorage(VATSetting.key) private var isVATRegistered = VATSetting.defaultValue
    @Query private var categories: [ExpenseCategory]

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
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
                    }

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
}

#Preview("Dark") {
    SettingsView()
        .modelContainer(SettingsPreviewData.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    SettingsView()
        .modelContainer(SettingsPreviewData.container)
        .dynamicTypeSize(.accessibility3)
}
