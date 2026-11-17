import Foundation

extension LocalizedStringResource {
    /// The resource resolved to a `String` in `locale`, for accessibility
    /// labels and composed texts that cannot stay a `LocalizedStringResource`.
    func resolved(in locale: Locale) -> String {
        var resource = self
        resource.locale = locale
        return String(localized: resource)
    }
}
