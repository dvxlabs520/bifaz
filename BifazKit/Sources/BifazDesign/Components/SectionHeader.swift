import SwiftUI

/// A screen section heading ("To review", "Latest expenses") with an optional
/// trailing caption such as a count or a total.
public struct SectionHeader: View {
    private let title: LocalizedStringResource
    private let trailing: LocalizedStringResource?

    public init(_ title: LocalizedStringResource, trailing: LocalizedStringResource? = nil) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
            Text(title)
                .font(.bifazSectionTitle)
                .foregroundStyle(Color.bifazInk)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: BifazSpacing.xs)
            if let trailing {
                Text(trailing)
                    .font(.bifazCaption)
                    .foregroundStyle(Color.bifazInkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light") {
    SectionHeaderSamples()
}

#Preview("Dark") {
    SectionHeaderSamples().preferredColorScheme(.dark)
}

#Preview("Large text") {
    SectionHeaderSamples().dynamicTypeSize(.accessibility3)
}

private struct SectionHeaderSamples: View {
    var body: some View {
        VStack(spacing: BifazSpacing.l) {
            SectionHeader("À vérifier", trailing: "3 dépenses")
            SectionHeader("Dernières dépenses")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bifazPaper)
    }
}
