import Foundation
@testable import BifazModels

func decimal(_ string: String) -> Decimal {
    Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
}

/// `Testing` also exports a `Tag`; make the model one win inside this module.
typealias Tag = BifazModels.Tag

// MARK: - Domain-layer helpers

import SwiftData

/// Fresh in-memory store. Keep the returned container alive for as long as its context is used.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    try BifazStore.makeContainer(inMemory: true)
}

/// Gregorian calendar fixed to Europe/Paris, so date maths never depends on the machine.
let parisCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

func parisDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
    parisCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

let frLocale = Locale(identifier: "fr_FR")
let enLocale = Locale(identifier: "en_US")
