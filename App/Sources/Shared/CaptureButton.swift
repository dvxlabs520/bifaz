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
            .accessibilityIdentifier("ui.captureManual")
        } label: {
            // A plain dark disc, not a tinted Liquid Glass button: the menu morphs
            // out of (and back into) a glass button's tint, which put the dark
            // menu text on a dark background while it closed.
            BifazIconView(.plus, size: 24, relativeTo: .title2)
                .foregroundStyle(Color.bifazPaper)
                .frame(width: side, height: side)
                .background(Color.bifazInk, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .contentShape(Circle())
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("capture.label"))
        .accessibilityIdentifier("ui.captureButton")
        .accessibilityHint(Text("capture.hint"))
    }
}

extension View {
    /// Places the capture button at the bottom trailing corner, above the tab bar.
    func captureButtonOverlay() -> some View {
        overlay(alignment: .bottomTrailing) {
            FloatingCaptureButton()
                .padding(.trailing, BifazSpacing.screen)
                .padding(.bottom, BifazSpacing.m)
        }
    }

    /// Hides the capture button while this scroll view moves down, shows it again
    /// when it moves up or stops (so it does not sit on amounts while reading a list).
    func hidesCaptureButtonWhileScrolling() -> some View {
        modifier(CaptureButtonScrollHiding())
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

/// The capture button, slid away while a list scrolls down. With Reduce Motion it
/// only fades; with VoiceOver on it never hides (see `CaptureButtonScrollHiding`).
private struct FloatingCaptureButton: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hidden = navigation.isCaptureButtonHidden
        CaptureButton()
            .offset(y: hidden && !reduceMotion ? 96 : 0)
            .opacity(hidden ? 0 : 1)
            .allowsHitTesting(!hidden)
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.25), value: hidden)
    }
}

private struct CaptureButtonScrollHiding: ViewModifier {
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    /// Points of movement before the button reacts (ignores tiny jitters).
    private static let threshold: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { old, new in
                guard !voiceOverEnabled else { return setHidden(false) }
                if new <= 0 {
                    setHidden(false)
                } else if new - old > Self.threshold {
                    setHidden(true)
                } else if old - new > Self.threshold {
                    setHidden(false)
                }
            }
            .onScrollPhaseChange { _, phase in
                if phase == .idle { setHidden(false) }
            }
            .onDisappear { setHidden(false) }
    }

    private func setHidden(_ hidden: Bool) {
        if navigation.isCaptureButtonHidden != hidden { navigation.isCaptureButtonHidden = hidden }
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
