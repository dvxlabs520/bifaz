import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Category management: one list per space, reorderable, editable and deletable.
struct CategoriesView: View {
    private enum EditorTarget: Identifiable {
        case new
        case edit(ExpenseCategory)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let category): category.id.uuidString
            }
        }
    }

    @State private var space: Space = .pro
    @State private var editor: EditorTarget?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: BifazSpacing.xs) {
                ForEach(Space.allCases) { option in
                    FilterChip(
                        option.title,
                        icon: option.icon,
                        symbolTint: option.color,
                        isSelected: space == option
                    ) {
                        space = option
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, BifazSpacing.l)
            .padding(.vertical, BifazSpacing.s)

            CategoryList(space: space) { category in
                editor = .edit(category)
            }
            .id(space)
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(Text("categories.title", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editMode = editMode.isEditing ? .inactive : .active
                } label: {
                    if editMode.isEditing {
                        Text("categories.done", tableName: "Settings")
                    } else {
                        Text("categories.edit", tableName: "Settings")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = .new
                } label: {
                    BifazIconView(.plus)
                }
                .accessibilityLabel(Text("categories.add", tableName: "Settings"))
            }
        }
        .sheet(item: $editor) { target in
            switch target {
            case .new:
                CategoryEditorView(category: nil, space: space)
            case .edit(let category):
                CategoryEditorView(category: category, space: space)
            }
        }
        .bifazScreen()
    }
}

/// The categories of one space.
private struct CategoryList: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [ExpenseCategory]
    @State private var pendingDeletion: ExpenseCategory?
    @State private var saveFailed = false
    @State private var deletions = 0

    private let space: Space
    private let onEdit: (ExpenseCategory) -> Void

    init(space: Space, onEdit: @escaping (ExpenseCategory) -> Void) {
        self.space = space
        self.onEdit = onEdit
        let raw = space.rawValue
        _categories = Query(
            filter: #Predicate<ExpenseCategory> { $0.spaceRawValue == raw },
            sort: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
    }

    var body: some View {
        Group {
            if categories.isEmpty {
                ScrollView {
                    EmptyStateView(
                        title: LocalizedStringResource("categories.empty.title", table: "Settings"),
                        message: LocalizedStringResource("categories.empty.message", table: "Settings")
                    )
                    .padding(.horizontal, BifazSpacing.l)
                    .padding(.top, BifazSpacing.xl)
                }
            } else {
                list
            }
        }
        .confirmationDialog(
            Text("category.delete.title \(pendingDeletion?.name ?? "")", tableName: "Settings"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { category in
            Button(role: .destructive) {
                delete(category)
            } label: {
                Text("category.delete.action", tableName: "Settings")
            }
        } message: { category in
            let count = category.expenses?.count ?? 0
            if count == 0 {
                Text("category.delete.message.none", tableName: "Settings")
            } else {
                Text("category.delete.message \(count)", tableName: "Settings")
            }
        }
        .alert(Text("category.error.title", tableName: "Settings"), isPresented: $saveFailed) {
            Button {} label: { Text("category.error.ok", tableName: "Settings") }
        }
        .sensoryFeedback(.warning, trigger: deletions)
    }

    private var list: some View {
        List {
            ForEach(categories) { category in
                Button {
                    onEdit(category)
                } label: {
                    row(category)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.bifazPaper)
                .listRowSeparatorTint(.bifazHairline)
                .listRowInsets(EdgeInsets(
                    top: BifazSpacing.xxs,
                    leading: BifazSpacing.l,
                    bottom: BifazSpacing.xxs,
                    trailing: BifazSpacing.l
                ))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeletion = category
                    } label: {
                        Text("category.delete.action", tableName: "Settings")
                    }
                }
            }
            .onMove(perform: move)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bifazPaper)
        .contentMargins(.bottom, 96, for: .scrollContent)
    }

    private func row(_ category: ExpenseCategory) -> some View {
        let count = category.expenses?.count ?? 0
        return HStack(spacing: BifazSpacing.m) {
            CategoryIcon(icon: category.icon, tint: space.color, background: space.tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(category.displayName)
                    .font(.bifazBody)
                    .foregroundStyle(.bifazInk)
                Text("category.expenseCount \(count)", tableName: "Settings")
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazInkSecondary)
            }
            Spacer(minLength: BifazSpacing.xs)
            BifazIconView(.chevronRight, size: 14, relativeTo: .body)
                .foregroundStyle(.bifazInkSecondary)
        }
        .padding(.vertical, BifazSpacing.xs)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("category.row.hint", tableName: "Settings"))
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: source, toOffset: destination)
        renumber(ordered)
        save()
    }

    private func delete(_ category: ExpenseCategory) {
        let remaining = categories.filter { $0.persistentModelID != category.persistentModelID }
        modelContext.delete(category)
        renumber(remaining)
        deletions += 1
        save()
    }

    private func renumber(_ ordered: [ExpenseCategory]) {
        for (index, category) in ordered.enumerated() where category.sortOrder != index {
            category.sortOrder = index
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Log.app.error("Saving categories failed: \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            saveFailed = true
        }
    }
}

// MARK: - Previews

private enum CategoriesPreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            let software = ExpenseCategory(name: "Logiciels", iconName: "software", space: .pro, sortOrder: 0)
            let meals = ExpenseCategory(name: "Repas", iconName: "meal", space: .pro, sortOrder: 1)
            let transport = ExpenseCategory(name: "Déplacements", iconName: "transport", space: .pro, sortOrder: 2)
            let groceries = ExpenseCategory(name: "Courses", iconName: "groceries", space: .personal, sortOrder: 0)
            for category in [software, meals, transport, groceries] { context.insert(category) }
            context.insert(Expense(amount: 24, merchant: "Figma", space: .pro, category: software))
            context.insert(Expense(amount: 12, merchant: "Notion", space: .pro, category: software))
            context.insert(Expense(amount: 18, merchant: "Brasserie", space: .pro, category: meals))
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}

#Preview("Light") {
    NavigationStack { CategoriesView() }
        .modelContainer(CategoriesPreviewData.container)
}

#Preview("Dark") {
    NavigationStack { CategoriesView() }
        .modelContainer(CategoriesPreviewData.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    NavigationStack { CategoriesView() }
        .modelContainer(CategoriesPreviewData.container)
        .dynamicTypeSize(.accessibility3)
}
