import UIKit
import BifazDesign

/// UIKit appearance that SwiftUI does not expose: semibold SF navigation
/// titles in Ink, like the rest of the calm type scale.
enum Appearance {
    static func configureNavigationBars() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [
            .font: font(for: .largeTitle, weight: .semibold),
            .foregroundColor: BifazPalette.ink.uiColor,
        ]
        appearance.titleTextAttributes = [
            .font: font(for: .headline, weight: .semibold),
            .foregroundColor: BifazPalette.ink.uiColor,
        ]
    }

    /// SF Pro at the Dynamic Type size of `style`.
    private static func font(for style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let size = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style).pointSize
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: weight))
    }
}
