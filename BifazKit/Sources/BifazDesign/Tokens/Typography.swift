import SwiftUI

/// Bifaz type scale: SF Pro throughout, regular and medium weights, so the
/// interface stays calm and the numbers carry the hierarchy. Every style is a
/// Dynamic Type text style. Amounts always use tabular figures so they line up.
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
}
