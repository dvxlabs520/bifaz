import SwiftUI

/// The body of the "Delete this expense?" confirmation, in the history and in
/// the edit form. Names the merchant when there is one; otherwise a neutral
/// sentence, so no empty name is ever interpolated.
struct DeleteExpenseMessage: View {
    let merchant: String

    var body: some View {
        if merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("history.delete.message.noMerchant", tableName: "History")
        } else {
            Text("history.delete.message \(merchant)", tableName: "History")
        }
    }
}
