import SwiftUI

/// Bifaz type scale, v2 (PLAN.md §3): three system voices, all Dynamic Type.
/// - SF Pro for the interface (regular and medium; numbers carry the hierarchy);
/// - SF Mono in small capitals for data labels ("LIMIT", "SPENT", month names);
/// - New York only for the context sentences of the Summary and budgets (phase 6).
/// Amounts always use tabular figures so they line up.
public extension Font {
    /// The month total at the top of Summary. 34 pt medium, tabular.
    static let bifazAmountHero = Font.system(.largeTitle, weight: .medium).monospacedDigit()
    /// Amounts on cards. 22 pt medium, tabular.
    static let bifazAmountMedium = Font.system(.title2, weight: .medium).monospacedDigit()
    /// Amounts in list rows. 17 pt regular, tabular.
    static let bifazAmount = Font.system(.body).monospacedDigit()

    /// Section headings inside a screen ("To review", "Latest expenses").
    static let bifazSectionTitle = Font.system(.headline)
    /// Prominent text in a block (empty-state heading, card title).
    static let bifazTitle = Font.system(.title3, weight: .semibold)
    /// Row titles and body copy.
    static let bifazBody = Font.system(.body)
    /// Emphasised body (buttons).
    static let bifazHeadline = Font.system(.body, weight: .medium)
    /// Filter chips and secondary copy.
    static let bifazSubheadline = Font.system(.subheadline)
    /// Subtitles, dates, captions.
    static let bifazCaption = Font.system(.footnote)
    /// Small labels and badges.
    static let bifazLabel = Font.system(.caption, weight: .medium)

    /// Data labels in SF Mono ("GASTADO", "LÍMITE", "NOV. 2026"). Use with
    /// `.bifazDataLabel()` for the capitals, tracking and colour.
    /// Caption, not caption2: the accessibility audit reports caption2 text as
    /// "Dynamic Type partially unsupported" (checked on three iPhones).
    static let bifazData = Font.system(.caption, design: .monospaced, weight: .medium)
    /// Context sentences in New York ("At this pace you'll be €52 short"). Phase 6 fills them.
    static let bifazContext = Font.system(.title3, design: .serif)
    /// Title of a compact header (small, centred).
    static let bifazHeaderTitle = Font.system(.subheadline, weight: .semibold)
}

public extension View {
    /// SF Mono small capitals in secondary ink, slightly tracked: the voice of data labels.
    func bifazDataLabel() -> some View {
        font(.bifazData)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Color.bifazInkSecondary)
    }

    /// A context sentence in New York (phase 6 writes them).
    func bifazContextSentence() -> some View {
        font(.bifazContext)
            .foregroundStyle(Color.bifazInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
