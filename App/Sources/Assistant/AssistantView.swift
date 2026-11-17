import SwiftUI
import BifazDesign

/// Assistant tab. Phase 0: what it will do and example questions (it arrives in phase 9).
struct AssistantView: View {
    private let examples: [LocalizedStringResource] = [
        "assistant.example.restaurants",
        "assistant.example.vat",
        "assistant.example.biggest",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EmptyStateView(title: "assistant.empty.title", message: "assistant.empty.message")

                    SectionHeader("assistant.examples")
                        .padding(.top, BifazSpacing.xxl)
                        .padding(.bottom, BifazSpacing.xs)

                    ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                        if index > 0 { HairlineDivider(leadingInset: BifazSpacing.xxl) }
                        HStack(spacing: BifazSpacing.s) {
                            Image(systemName: "text.bubble")
                                .foregroundStyle(.bifazInkSecondary)
                                .frame(width: BifazSpacing.l)
                                .accessibilityHidden(true)
                            Text(example)
                                .font(.bifazBody)
                                .foregroundStyle(.bifazInk)
                        }
                        .padding(.vertical, BifazSpacing.s)
                    }
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.top, BifazSpacing.xs)
                .padding(.bottom, BifazSpacing.xxxl * 2)
            }
            .navigationTitle("tab.assistant")
            .bifazScreen()
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
