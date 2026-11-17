import UIKit
import BifazDesign

/// UIKit appearance that SwiftUI does not expose: New York for navigation titles.
enum Appearance {
    static func configureNavigationBars() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [
            .font: serifFont(for: .largeTitle, weight: .semibold),
            .foregroundColor: BifazPalette.ink.uiColor,
        ]
        appearance.titleTextAttributes = [
            .font: serifFont(for: .headline, weight: .semibold),
            .foregroundColor: BifazPalette.ink.uiColor,
        ]
    }

    /// New York at the Dynamic Type size of `style`.
    private static func serifFont(for style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        let descriptor = base.withDesign(.serif) ?? base
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: 0))
    }
}
