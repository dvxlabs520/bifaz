import SwiftUI
import BifazModels
import BifazDesign

/// The capture button, floating over every tab.
///
/// Opens the capture menu: scan, photo, file, or an expense without receipt,
/// in the space of the current filter. Phase 7 adds "Start expense session".
struct CaptureButton: View {
    @Environment(AppNavigation.self) private var navigation
    @AppStorage("spaceFilter") private var spaceFilter: SpaceFilter = .all
    @ScaledMetric(relativeTo: .title2) private var side: CGFloat = 56

    var body: some View {
        Menu {
            CaptureMenuItems { source in navigation.capture(from: source, filter: spaceFilter) }
            Divider()
            Button {
                navigation.addExpense(filter: spaceFilter)
            } label: {
                Label { Text("capture.manual") } icon: { BifazIcon.edit.image }
            }
        } label: {
            BifazIconView(.plus, size: 24, relativeTo: .title2)
                .foregroundStyle(Color.bifazPaper)
                .frame(width: side, height: side)
        }
        .menuOrder(.fixed)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.bifazInk)
        .accessibilityLabel(Text("capture.label"))
        .accessibilityIdentifier("ui.captureButton")
        .accessibilityHint(Text("capture.hint"))
    }
}

extension View {
    /// Places the capture button at the bottom trailing corner, above the tab bar.
    func captureButtonOverlay() -> some View {
        overlay(alignment: .bottomTrailing) {
            CaptureButton()
                .padding(.trailing, BifazSpacing.screen)
                .padding(.bottom, BifazSpacing.m)
        }
    }

    /// Leaves room under scrolling content so its last row ends above the
    /// floating capture button (and so above the tab bar). Scales with Dynamic Type.
    func captureButtonClearance() -> some View {
        modifier(CaptureButtonClearance())
    }

    /// Standard screen chrome: Paper background and room for the capture button.
    func bifazScreen() -> some View {
        background(Color.bifazPaper)
            .captureButtonClearance()
            .captureButtonOverlay()
    }
}

private struct CaptureButtonClearance: ViewModifier {
    /// Same metric as `CaptureButton.side`.
    @ScaledMetric(relativeTo: .title2) private var side: CGFloat = 56

    func body(content: Content) -> some View {
        // Button height + its bottom padding + breathing room above it.
        content.contentMargins(.bottom, side + BifazSpacing.m + BifazSpacing.m, for: .scrollContent)
    }
}

#Preview {
    Color.bifazPaper
        .ignoresSafeArea()
        .captureButtonOverlay()
        .environment(AppNavigation())
}
