import Foundation
@testable import BifazModels

func decimal(_ string: String) -> Decimal {
    Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
}

/// `Testing` also exports a `Tag`; make the model one win inside this module.
typealias Tag = BifazModels.Tag
