import Foundation
import BifazModels

/// Brand and shared texts that live in BifazKit's String Catalog.
public enum BrandStrings {
    /// "Bifaz". Not translated, but kept in the catalog like every visible text.
    public static let name = LocalizedStringResource("brand.name", bundle: .module)
    /// "Two sides, one clear ledger."
    public static let tagline = LocalizedStringResource("brand.tagline", bundle: .module)
}

public extension Space {
    /// Localised name: "Pro" / "Personal".
    var title: LocalizedStringResource {
        switch self {
        case .pro: LocalizedStringResource("space.pro", bundle: .module)
        case .personal: LocalizedStringResource("space.personal", bundle: .module)
        }
    }
}

public extension SpaceFilter {
    /// Localised name: "Pro" / "Personal" / "All".
    var title: LocalizedStringResource {
        switch self {
        case .pro: Space.pro.title
        case .personal: Space.personal.title
        case .all: LocalizedStringResource("space.all", bundle: .module)
        }
    }
}
