import Foundation
import SwiftData
import Testing
@testable import BifazModels

/// 5,000 generated expenses over two years: how long the Summary of one month takes.
/// The bound is loose (simulators vary); the measured times are printed for the notes.
@MainActor
@Suite("Summary performance", .serialized)
struct SummaryPerformanceTests {
    @Test("Summary of a month with 5,000 expenses in the store")
    func fiveThousand() async throws {
        let container = try makeTestContainer()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        try CategorySeeder.seedIfNeeded(in: context)
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        var rng = SeededGenerator(seed: 5000)
        let start = parisDate(2024, 12, 1)
        for _ in 0..<5000 {
            let space: Space = Bool.random(using: &rng) ? .pro : .personal
            let amount = Decimal(Int.random(in: 100...30_000, using: &rng)) / 100
            let expense = Expense(amount: amount, date: start.addingTimeInterval(Double.random(in: 0..<(730 * 86_400), using: &rng)),
                                  merchant: "Commerce", space: space,
                                  category: categories.filter { $0.space == space }.randomElement(using: &rng))
            context.insert(expense)
            if space == .pro {
                ExpenseService.setVATLines([.computed(total: amount, rate: decimal("0.20"))], on: expense, in: context)
            }
        }
        try context.save()

        let clock = ContinuousClock()
        let loader = SummaryLoader(modelContainer: container)
        var times: [Duration] = []
        var month = ExpenseGrouping.monthInterval(containing: parisDate(2026, 11, 15), calendar: parisCalendar)
        for _ in 0..<12 {
            let current = month
            let elapsed = try await clock.measure {
                let result = try await loader.load(month: current, space: .all, now: parisDate(2026, 11, 17), calendar: parisCalendar)
                #expect(result.summary.totals.count > 0)
            }
            times.append(elapsed)
            month = ExpenseGrouping.monthInterval(containing: month.start.addingTimeInterval(-86_400), calendar: parisCalendar)
        }
        let ms = times.map { Double($0.components.attoseconds) / 1e15 + Double($0.components.seconds) * 1000 }
        let sorted = ms.sorted()
        print("BIFAZ-PERF summary 5000 (background loader): first open \(Int(ms[0])) ms; each previous month: median \(Int(sorted[sorted.count / 2])) ms, max \(Int(ms.dropFirst().max()!)) ms")
        // After a save the cache is dropped: a full read again.
        let fresh = try await clock.measure {
            _ = try await loader.load(month: month, space: .pro, version: 1, now: parisDate(2026, 11, 17), calendar: parisCalendar)
        }
        print("BIFAZ-PERF summary 5000 after a save (no cache): \(fresh)")
        #expect(sorted[sorted.count / 2] < 250)
    }
}
