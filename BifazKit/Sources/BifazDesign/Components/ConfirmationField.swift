import SwiftUI
import BifazModels

/// A labelled text field for the receipt confirmation screen. A trailing
/// indicator (symbol and word) shows how sure the reader was about the value;
/// low confidence also outlines the field. `nil` means the value was typed by
/// hand and no indicator is shown.
public struct ConfirmationField: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let label: LocalizedStringResource
    @Binding private var text: String
    private let confidence: ReadingConfidence?

    public init(_ label: LocalizedStringResource, text: Binding<String>, confidence: ReadingConfidence? = nil) {
        self.label = label
        _text = text
        self.confidence = confidence
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xxs) {
            Text(label)
                .font(.bifazSubheadline)
                .foregroundStyle(Color.bifazInkSecondary)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BifazSpacing.xs) { field; indicator }
            } else {
                HStack(spacing: BifazSpacing.xs) { field; indicator }
            }
        }
        .padding(BifazSpacing.s)
        .background(Color.bifazSurface, in: shape)
        .overlay(
            shape.strokeBorder(
                confidence == .low ? Color.bifazError : Color.bifazHairline,
                lineWidth: confidence == .low ? 2 : 1
            )
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous)
    }

    private var field: some View {
        TextField(text: $text, prompt: Text(verbatim: "—")) {
            Text(label)
        }
        .font(.bifazBody)
        .foregroundStyle(Color.bifazInk)
        .accessibilityHint(hintText)
    }

    @ViewBuilder
    private var indicator: some View {
        if let confidence {
            HStack(spacing: BifazSpacing.xxs) {
                Image(systemName: confidence.symbolName)
                Text(confidence.word)
            }
            .font(.bifazLabel)
            .foregroundStyle(confidence.color)
            .accessibilityHidden(true)
        }
    }

    private var hintText: String {
        guard let confidence else { return "" }
        let word = confidence.word.resolved(in: locale)
        return LocalizedStringResource("confidence.accessibility \(word)", bundle: .module).resolved(in: locale)
    }
}

private extension ReadingConfidence {
    var word: LocalizedStringResource {
        switch self {
        case .high: LocalizedStringResource("confidence.high", bundle: .module)
        case .medium: LocalizedStringResource("confidence.medium", bundle: .module)
        case .low: LocalizedStringResource("confidence.low", bundle: .module)
        }
    }

    var symbolName: String {
        switch self {
        case .high: "checkmark.circle.fill"
        case .medium: "questionmark.circle.fill"
        case .low: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .high: .bifazSuccess
        case .medium: .bifazWarning
        case .low: .bifazError
        }
    }
}

#Preview("Light") {
    ConfirmationFieldSamples()
}

#Preview("Dark") {
    ConfirmationFieldSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    ConfirmationFieldSamples().dynamicTypeSize(.accessibility3)
}

private struct ConfirmationFieldSamples: View {
    @State private var merchant = "Monoprix"
    @State private var total = "42,80"
    @State private var date = "17 nov."
    @State private var note = ""

    var body: some View {
        VStack(spacing: BifazSpacing.m) {
            ConfirmationField("Commerçant", text: $merchant, confidence: .high)
            ConfirmationField("Date", text: $date, confidence: .medium)
            ConfirmationField("Total", text: $total, confidence: .low)
            ConfirmationField("Note", text: $note)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bifazPaper)
    }
}
