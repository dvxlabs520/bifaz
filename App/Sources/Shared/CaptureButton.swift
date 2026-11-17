import SwiftUI
import BifazDesign

/// The capture button, floating over every tab.
///
/// Phase 0: present but without function. Phase 1 opens quick expense entry;
/// phase 2 adds scanning and import; phase 7 adds "Start expense session".
struct CaptureButton: View {
    @ScaledMetric(relativeTo: .title2) private var side: CGFloat = 56

    var body: some View {
        Button {
            // Intentionally empty until phase 1.
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
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
                .padding(.trailing, BifazSpacing.l)
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
}
