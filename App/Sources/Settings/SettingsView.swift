import SwiftUI
import BifazDesign

/// Settings tab. Phase 0: brand header and "About"; real settings arrive with their features.
struct SettingsView: View {
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
                    .padding(.bottom, BifazSpacing.xxl)

                    SectionHeader("settings.about")
                        .padding(.bottom, BifazSpacing.xs)
                    HairlineDivider()
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
                    HairlineDivider()

                    Text("settings.footer")
                        .font(.bifazCaption)
                        .foregroundStyle(.bifazInkSecondary)
                        .padding(.top, BifazSpacing.s)
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.top, BifazSpacing.xs)
                .padding(.bottom, BifazSpacing.xxxl * 2)
            }
            .navigationTitle("tab.settings")
            .bifazScreen()
        }
    }
}

#Preview("Light") {
    SettingsView()
}

#Preview("Dark") {
    SettingsView()
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    SettingsView()
        .dynamicTypeSize(.accessibility3)
}
