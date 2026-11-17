import SwiftUI

/// Bifaz type scale. Every style is built on a Dynamic Type text style, so it
/// scales with the user's text size.
///
/// - New York (the system serif) for titles and large amounts.
/// - SF Pro for the interface.
/// - Tabular figures (`monospacedDigit`) wherever numbers line up in lists.
public extension Font {
    /// Screen titles and the wordmark. New York.
    static let bifazDisplay = Font.system(.largeTitle, design: .serif, weight: .semibold)
    /// Section and card titles. New York.
    static let bifazTitle = Font.system(.title2, design: .serif, weight: .semibold)
    /// Hero amount (month total). New York, tabular figures.
    static let bifazAmountLarge = Font.system(.largeTitle, design: .serif, weight: .semibold).monospacedDigit()
    /// Amount on a card. New York, tabular figures.
    static let bifazAmountMedium = Font.system(.title2, design: .serif, weight: .semibold).monospacedDigit()
    /// Amount in a list row. SF Pro, tabular figures.
    static let bifazAmount = Font.system(.body, design: .default, weight: .semibold).monospacedDigit()

    /// Emphasised interface text. SF Pro.
    static let bifazHeadline = Font.system(.headline)
    /// Body text. SF Pro.
    static let bifazBody = Font.system(.body)
    /// Secondary interface text. SF Pro.
    static let bifazSubheadline = Font.system(.subheadline)
    /// Metadata, captions. SF Pro.
    static let bifazCaption = Font.system(.footnote)
    /// Small labels on chips and badges. SF Pro.
    static let bifazLabel = Font.system(.caption, weight: .medium)
}
