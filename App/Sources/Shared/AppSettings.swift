import SwiftUI
import BifazModels

/// "Download ECB exchange rates" (phase 4). On by default; off, Bifaz never uses
/// the network and foreign amounts take a typed rate or euro amount.
enum ExchangeRateSetting {
    static let key = "downloadECBRates"
    static let defaultValue = true
}

/// The three local reminders, stored as JSON in the app's defaults (App Group).
enum ReminderSettingsStore {
    static let key = "reminderSettings"

    static func load(from defaults: UserDefaults = AppDefaults.shared) -> ReminderSettings {
        guard let raw = defaults.string(forKey: key), let settings = ReminderSettings(rawValue: raw) else { return ReminderSettings() }
        return settings
    }
}

/// Lets `@AppStorage(ReminderSettingsStore.key)` hold the settings directly.
extension ReminderSettings: @retroactive RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ReminderSettings.self, from: data) else { return nil }
        self = decoded
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
