import SwiftUI
import BifazDesign

/// Assistant tab. Phase 0: empty state only (the assistant arrives in phase 9).
struct AssistantView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                EmptyStateView(
                    title: "assistant.empty.title",
                    message: "assistant.empty.message",
                    illustration: .symbol("sparkles")
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, BifazSpacing.m)
                .padding(.top, BifazSpacing.xxxl)
                .padding(.bottom, BifazSpacing.xxxl * 2)
            }
            .background(Color.bifazPaper)
            .navigationTitle("tab.assistant")
            .captureButtonOverlay()
        }
    }
}

#Preview("Light") {
    AssistantView()
}

#Preview("Dark") {
    AssistantView()
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    AssistantView()
        .dynamicTypeSize(.accessibility3)
}
