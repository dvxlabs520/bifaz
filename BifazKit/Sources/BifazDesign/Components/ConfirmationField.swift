import SwiftUI
import BifazModels

/// A labelled text field for the receipt confirmation screen. A small tag on
/// the label row (symbol and word, on a tinted capsule) shows how sure the
/// reader was about the value; low confidence also outlines the field in the
/// error colour. `nil` means the value was typed by hand and no tag is shown.
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
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BifazSpacing.xxs) { caption; tag }
            } else {
                HStack(alignment: .center, spacing: BifazSpacing.xs) {
                    caption
                    Spacer(minLength: BifazSpacing.xs)
                    tag
                }
            }
            field
        }
    }

    private var caption: some View {
        Text(label)
            .font(.bifazCaption)
            .foregroundStyle(Color.bifazInkSecondary)
    }

    private var field: some View {
        let shape = RoundedRectangle(cornerRadius: BifazRadius.small, style: .continuous)
        return TextField(text: $text, prompt: Text(verbatim: "—")) {
            Text(label)
        }
        .font(.bifazBody)
        .foregroundStyle(Color.bifazInk)
        .padding(BifazSpacing.s)
        .background(Color.bifazSurface, in: shape)
        .overlay(shape.strokeBorder(confidence == .low ? Color.bifazError : .bifazHairline, lineWidth: 1))
        .accessibilityHint(hintText)
    }

    @ViewBuilder
    private var tag: some View {
        if let confidence {
            HStack(spacing: BifazSpacing.xxs) {
                BifazIconView(confidence.icon, size: 14, relativeTo: .caption)
                Text(confidence.word)
            }
            .font(.bifazLabel)
            .foregroundStyle(confidence.color)
            .padding(.horizontal, BifazSpacing.xs)
            .padding(.vertical, BifazSpacing.xxs)
            .background(confidence.tint, in: Capsule())
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

    var icon: BifazIcon {
        switch self {
        case .high: .check
        case .medium: .info
        case .low: .warning
        }
    }

    var color: Color {
        switch self {
        case .high: .bifazSuccess
        case .medium: .bifazWarning
        case .low: .bifazError
        }
    }

    var tint: Color {
        switch self {
        case .high: .bifazSuccessTint
        case .medium: .bifazWarningTint
        case .low: .bifazErrorTint
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
    @State private var date = "17 nov."
    @State private var total = "42,80"
    @State private var note = ""

    var body: some View {
        VStack(spacing: BifazSpacing.m) {
            ConfirmationField("Commerçant", text: $merchant, confidence: .high)
            ConfirmationField("Date", text: $date, confidence: .medium)
            ConfirmationField("Total", text: $total, confidence: .low)
            ConfirmationField("Note", text: $note)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
