import SwiftUI

/// Bifaz's own icon set: thin outline icons on a 24 pt grid, bundled as
/// template vector images in `Icons.xcassets`. Use `BifazIconView` for
/// Dynamic Type scaling, or `image` when a plain `Image` is needed.
public enum BifazIcon: String, CaseIterable, Sendable {
    // Navigation
    case summary, expenses, assistant, settings
    // Actions and interface
    case plus, scan, camera, `import`, search, filter, close, check
    case chevronRight, chevronDown, edit, trash, calendar, note
    case receipt, receiptPending, session, warning, info, share, lock, percent
    // Spaces
    case pro, personal
    /// The Bifaz coin: both spaces together. Asset is named `spaceAll` because
    /// Xcode disallows `all` as an asset symbol name.
    case all = "spaceAll"
    // Categories
    case transport, car, fuel, meal, coffee, lodging, equipment, software
    case phone, services, training, office, bankFees, groceries, furniture
    case health, leisure, shopping, subscriptions, travel, education, pets
    case gift, clothing, taxes, other

    /// The icon as a template image: it takes the foreground style of its context.
    public var image: Image {
        Image(rawValue, bundle: .module).renderingMode(.template)
    }

    /// Icons that can identify an expense category, in picker order.
    public static let categoryIcons: [BifazIcon] = [
        .transport,
        .car,
        .fuel,
        .meal,
        .coffee,
        .lodging,
        .equipment,
        .software,
        .phone,
        .services,
        .training,
        .office,
        .bankFees,
        .groceries,
        .furniture,
        .health,
        .leisure,
        .shopping,
        .subscriptions,
        .travel,
        .education,
        .pets,
        .gift,
        .clothing,
        .taxes,
        .other
    ]
}

/// An icon that scales with Dynamic Type relative to a text style. Hidden from
/// accessibility by default: the surrounding label carries the meaning.
public struct BifazIconView: View {
    @ScaledMetric private var side: CGFloat
    private let icon: BifazIcon

    /// - Parameters:
    ///   - icon: The icon to draw.
    ///   - size: Point size at the default Dynamic Type setting.
    ///   - relativeTo: The text style the size scales with.
    public init(_ icon: BifazIcon, size: CGFloat = 20, relativeTo: Font.TextStyle = .body) {
        self.icon = icon
        _side = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
    }

    public var body: some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

#Preview("All icons") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
            ForEach(BifazIcon.allCases, id: \.self) { icon in
                BifazIconView(icon, size: 28)
                    .foregroundStyle(Color.bifazInk)
            }
        }
        .padding()
    }
    .background(Color.bifazPaper)
}
