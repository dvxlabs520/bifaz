import Foundation
import FoundationModels

/// Reads a receipt with Apple's on-device language model (Apple Intelligence),
/// using guided generation so the answer is always structured.
///
/// Never trusted blindly: `ReceiptReader` keeps a model value only when it can
/// be found in the recognised text, and cross-checks it with the rules.
enum ModelReceiptParser {
    @Generable(description: "Data printed on a French receipt or invoice")
    struct Extraction {
        @Guide(description: "Name of the shop or company that issued the receipt, as printed (the brand, not the address, not the customer)")
        var merchant: String?
        @Guide(description: "Purchase or invoice date in ISO format yyyy-MM-dd")
        var date: String?
        @Guide(description: "Total paid, VAT included (TTC / net à payer), digits with a dot as decimal separator, e.g. 42.50")
        var totalIncludingVAT: String?
        @Guide(description: "Main VAT rate in percent: 20, 10, 5.5, 2.1, or 0 when VAT is not applicable")
        var vatRatePercent: Double?
        @Guide(description: "Total VAT amount, digits with a dot, e.g. 7.08")
        var vatAmount: String?
    }

    /// Whether the model can run on this device right now.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func extract(from lines: [String]) async throws -> Extraction {
        let session = LanguageModelSession(instructions: """
            You read the text of French receipts and invoices recognised by OCR, which may contain \
            mistakes. Extract only values that are printed in the text; leave a field empty when it \
            is not there. Amounts use a comma as decimal separator in the text; answer with a dot. \
            The total is the amount paid including VAT, never a subtotal, an amount before tax (HT), \
            change given back (rendu) or a VAT amount.
            """)
        // Long invoices: the header and the totals are what matter.
        let text = lines.count > 90 ? (lines.prefix(30) + ["…"] + lines.suffix(60)).joined(separator: "\n")
                                    : lines.joined(separator: "\n")
        let response = try await session.respond(
            to: "Receipt text:\n\(text)",
            generating: Extraction.self,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 200)
        )
        return response.content
    }
}
