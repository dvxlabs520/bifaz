import Testing
@testable import BifazReading

@Suite("Model timeout")
struct ModelTimeoutTests {
    @Test("A slow operation is cut at the limit")
    func slowOperationTimesOut() async {
        await #expect(throws: ReceiptReader.ReadTimeout.self) {
            try await ReceiptReader.withTimeout(.milliseconds(50)) {
                try await Task.sleep(for: .seconds(5))
                return 1
            }
        }
    }

    @Test("A fast operation returns its value")
    func fastOperationReturns() async throws {
        let value = try await ReceiptReader.withTimeout(.seconds(5)) { 42 }
        #expect(value == 42)
    }

    @Test("Forcing the rules never asks the model")
    func rulesOnlyNotAsked() async {
        let reading = await ReceiptReader(useModel: false).read(lines: ["MONOPRIX", "TOTAL TTC  12,50 €"])
        #expect(reading.modelOutcome == .notAsked)
        #expect(reading.method == .rules)
    }
}
