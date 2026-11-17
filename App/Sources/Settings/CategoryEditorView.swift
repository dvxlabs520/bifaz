import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Sheet to create a category or edit an existing one.
struct CategoryEditorView: View {
    private static let maxNameLength = 40

    private let category: ExpenseCategory?
    private let space: Space

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var spaceCategories: [ExpenseCategory]
    @State private var name: String
    @State private var icon: BifazIcon
    @State private var saved = false
    @State private var saveFailed = false
    @ScaledMetric(relativeTo: .body) private var cellSide: CGFloat = 64

    init(category: ExpenseCategory?, space: Space) {
        self.category = category
        self.space = space
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? .other)
        let raw = space.rawValue
        _spaceCategories = Query(filter: #Predicate<ExpenseCategory> { $0.spaceRawValue == raw })
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        let target = Self.fold(trimmedName)
        return spaceCategories.contains {
            $0.persistentModelID != category?.persistentModelID && Self.fold($0.name) == target
        }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicate && !saved
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BifazSpacing.xl) {
                    HStack(spacing: BifazSpacing.xs) {
                        BifazIconView(space.icon, size: 16, relativeTo: .subheadline)
                            .foregroundStyle(space.color)
                        Text(space.title)
                            .font(.bifazSubheadline)
                            .foregroundStyle(.bifazInkSecondary)
                    }
                    .accessibilityElement(children: .combine)

                    nameField
                    iconPicker
                }
                .padding(.horizontal, BifazSpacing.l)
                .padding(.vertical, BifazSpacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.bifazPaper)
            .navigationTitle(
                category == nil
                    ? Text("editor.title.new", tableName: "Settings")
                    : Text("editor.title.edit", tableName: "Settings")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("editor.cancel", tableName: "Settings")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("editor.save", tableName: "Settings")
                    }
                    .disabled(!canSave)
                }
            }
            .alert(Text("category.error.title", tableName: "Settings"), isPresented: $saveFailed) {
                Button {} label: { Text("category.error.ok", tableName: "Settings") }
            }
            .sensoryFeedback(.success, trigger: saved)
        }
        .presentationBackground(Color.bifazPaper)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.xs) {
            SectionHeader(LocalizedStringResource("editor.name.header", table: "Settings"))
            TextField(
                text: $name,
                prompt: Text("editor.name.placeholder", tableName: "Settings")
            ) {
                Text("editor.name.header", tableName: "Settings")
            }
            .font(.bifazBody)
            .foregroundStyle(.bifazInk)
            .submitLabel(.done)
            .onSubmit(save)
            .onChange(of: name) {
                if name.count > Self.maxNameLength {
                    name = String(name.prefix(Self.maxNameLength))
                }
            }
            .frame(minHeight: 44)
            HairlineDivider()
            if isDuplicate && !trimmedName.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
                    BifazIconView(.warning, size: 14, relativeTo: .footnote)
                    Text("editor.name.duplicate", tableName: "Settings")
                }
                .font(.bifazCaption)
                .foregroundStyle(.bifazError)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: BifazSpacing.s) {
            SectionHeader(LocalizedStringResource("editor.icon.header", table: "Settings"))
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: cellSide), spacing: BifazSpacing.xs)],
                alignment: .center,
                spacing: BifazSpacing.xs
            ) {
                ForEach(BifazIcon.categoryIcons, id: \.self) { option in
                    let isSelected = option == icon
                    Button {
                        icon = option
                    } label: {
                        CategoryIcon(icon: option, tint: space.color, background: space.tint, side: 44)
                            .padding(BifazSpacing.xxs)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.bifazInk, lineWidth: isSelected ? 2 : 0)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isSelected)
                    .accessibilityLabel(Text(LocalizedStringKey("icon.\(option.rawValue)"), tableName: "Settings"))
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        if let category {
            category.name = trimmedName
            category.iconName = icon.rawValue
        } else {
            let next = (spaceCategories.map(\.sortOrder).max() ?? -1) + 1
            modelContext.insert(ExpenseCategory(
                name: trimmedName,
                iconName: icon.rawValue,
                space: space,
                sortOrder: next
            ))
        }
        do {
            try modelContext.save()
            saved = true
            Task {
                // Let the success haptic fire before the sheet goes away.
                try? await Task.sleep(for: .milliseconds(250))
                dismiss()
            }
        } catch {
            Log.app.error("Saving category failed: \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            saveFailed = true
        }
    }
}

// MARK: - Previews

private enum EditorPreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            context.insert(ExpenseCategory(name: "Logiciels", iconName: "software", space: .pro, sortOrder: 0))
            context.insert(ExpenseCategory(name: "Repas", iconName: "meal", space: .pro, sortOrder: 1))
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}

#Preview("Light") {
    CategoryEditorView(category: nil, space: .pro)
        .modelContainer(EditorPreviewData.container)
}

#Preview("Dark") {
    CategoryEditorView(category: nil, space: .personal)
        .modelContainer(EditorPreviewData.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    CategoryEditorView(category: nil, space: .pro)
        .modelContainer(EditorPreviewData.container)
        .dynamicTypeSize(.accessibility3)
}
