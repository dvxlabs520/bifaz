import SwiftUI
import BifazModels
import BifazDesign

/// The capture button, floating over every tab.
///
/// Opens quick add in the space of the current filter. Phase 2 adds scanning
/// and import here; phase 7 adds "Start expense session".
struct CaptureButton: View {
    @Environment(AppNavigation.self) private var navigation
    @AppStorage("spaceFilter") private var spaceFilter: SpaceFilter = .all
    @ScaledMetric(relativeTo: .title2) private var side: CGFloat = 56

    var body: some View {
        Button {
            navigation.addExpense(filter: spaceFilter)
        } label: {
            BifazIconView(.plus, size: 24, relativeTo: .title2)
                .foregroundStyle(Color.bifazPaper)
                .frame(width: side, height: side)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.bifazInk)
        .accessibilityLabel(Text("capture.label"))
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

    /// Standard screen chrome: Paper background and room for the capture button.
    func bifazScreen() -> some View {
        background(Color.bifazPaper)
            .captureButtonOverlay()
    }
}

#Preview {
    Color.bifazPaper
        .ignoresSafeArea()
        .captureButtonOverlay()
        .environment(AppNavigation())
}
