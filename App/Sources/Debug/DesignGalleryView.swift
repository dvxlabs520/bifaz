#if DEBUG
import SwiftUI
import BifazModels
import BifazDesign

/// Debug-only gallery of the design system with sample data, for design review
/// and screenshots. Open with the launch argument `-BifazDesignGallery YES`.
/// Section titles are component type names (developer-facing, not localized).
struct DesignGalleryView: View {
    @State private var filter: SpaceFilter = .all
    @State private var merchant = "SNCF"
    @State private var total = "87,00"

    private static let day: TimeInterval = 86_400
    private let now = Date.now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SpaceSelector(selection: $filter)
                    .padding(.bottom, BifazSpacing.xl)

                Text("summary.spentIn \(now.formatted(.dateTime.month(.wide)))")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
                AmountView(Decimal(string: "1284.50")!, style: .hero)
                    .padding(.top, BifazSpacing.xxs)
                SpaceSplitBar(pro: Decimal(string: "796.10")!, personal: Decimal(string: "488.40")!)
                    .padding(.top, BifazSpacing.s)

                section("ExpenseRow · pending")
                ExpenseRow(
                    merchant: "SNCF", categoryName: "Transport", categorySymbol: "tram.fill",
                    date: now.addingTimeInterval(-3 * Self.day), amount: 87,
                    space: .pro, receiptState: .pending
                )
                .padding(.horizontal, BifazSpacing.m)
                .bifazCard(padding: 0)

                section("ExpenseRow")
                ExpenseRow(
                    merchant: "Adobe", categoryName: "Logiciels", categorySymbol: "laptopcomputer",
                    date: now.addingTimeInterval(-5 * Self.day), amount: Decimal(string: "71.99")!,
                    space: .pro, receiptState: .attached
                )
                HairlineDivider(leadingInset: BifazSpacing.xxxl)
                ExpenseRow(
                    merchant: "Monoprix", categoryName: "Courses", categorySymbol: "cart.fill",
                    date: now.addingTimeInterval(-6 * Self.day), amount: Decimal(string: "23.40")!,
                    space: .personal, receiptState: .none
                )
                HairlineDivider(leadingInset: BifazSpacing.xxxl)
                ExpenseRow(
                    merchant: "Boulangerie Paul", categoryName: nil, categorySymbol: "fork.knife",
                    date: now.addingTimeInterval(-7 * Self.day), amount: Decimal(string: "6.80")!,
                    space: .personal, receiptState: .none
                )

                section("StatCard · BudgetBar")
                StatCard(title: "summary.vatPaid", amount: Decimal(string: "96.40")!, accent: .bifazPro)
                BudgetBar(spent: 240, limit: 300)
                    .padding(.top, BifazSpacing.m)

                section("CategoryChip · ReceiptThumbnail")
                HStack(spacing: BifazSpacing.xs) {
                    CategoryChip("Transport", symbolName: "tram.fill", tint: .bifazPro, isSelected: true)
                    CategoryChip("Courses", symbolName: "cart.fill", tint: .bifazPersonal)
                }
                HStack(spacing: BifazSpacing.s) {
                    ReceiptThumbnail(state: .attached)
                    ReceiptThumbnail(state: .pending)
                    ReceiptThumbnail(state: .none)
                }
                .padding(.top, BifazSpacing.s)

                section("ConfirmationField")
                ConfirmationField("field.merchant", text: $merchant, confidence: .high)
                ConfirmationField("field.total", text: $total, confidence: .low)
                    .padding(.top, BifazSpacing.s)

                section("Buttons")
                Button("action.addExpense") {}.buttonStyle(.bifazPrimary)
                Button("action.scanInvoice") {}.buttonStyle(.bifazSecondary)
                    .padding(.top, BifazSpacing.xs)
            }
            .padding(.horizontal, BifazSpacing.l)
            .padding(.vertical, BifazSpacing.xl)
        }
        .background(Color.bifazPaper)
    }

    private func section(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.bifazLabel)
            .foregroundStyle(.bifazInkSecondary)
            .padding(.top, BifazSpacing.xl)
            .padding(.bottom, BifazSpacing.xs)
    }
}

#Preview("Light") {
    DesignGalleryView()
}

#Preview("Dark") {
    DesignGalleryView()
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    DesignGalleryView()
        .dynamicTypeSize(.accessibility3)
}
#endif
