import SwiftUI
import BifazDesign

/// Settings tab. Phase 0: brand header and version; real settings arrive with their features.
struct SettingsView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: BifazSpacing.s) {
                        BifazWordmark()
                        Text(BrandStrings.tagline)
                            .font(.bifazSubheadline)
                            .foregroundStyle(.bifazInkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BifazSpacing.xl)
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent {
                        Text(verbatim: version)
                            .monospacedDigit()
                            .foregroundStyle(.bifazInkSecondary)
                    } label: {
                        Text("settings.version")
                            .foregroundStyle(.bifazInk)
                    }
                    .listRowBackground(Color.bifazSurface)
                } header: {
                    Text("settings.about")
                } footer: {
                    Text("settings.footer")
                        .foregroundStyle(.bifazInkSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bifazPaper)
            .navigationTitle("tab.settings")
            .captureButtonOverlay()
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
