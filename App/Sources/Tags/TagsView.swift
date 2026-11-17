import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

/// Management of client and project tags (Pro): add, rename, archive, delete.
struct TagsView: View {
    private enum Editor: Identifiable {
        case new
        case rename(Tag)

        var id: String {
            switch self {
            case .new: "new"
            case .rename(let tag): tag.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var kind: TagKind = .client
    @State private var editor: Editor?
    @State private var pendingDeletion: Tag?
    @State private var showsArchived = false
    @State private var saveFailed = false
    @State private var deletions = 0

    private var active: [Tag] { allTags.filter { $0.kind == kind && !$0.isArchived } }
    private var archived: [Tag] { allTags.filter { $0.kind == kind && $0.isArchived } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: BifazSpacing.xs) {
                ForEach(TagKind.allCases, id: \.self) { option in
                    FilterChip(
                        option == .client ? "tags.screen.clients" : "tags.screen.projects",
                        icon: option.icon,
                        symbolTint: .bifazPro,
                        isSelected: kind == option
                    ) {
                        kind = option
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, BifazSpacing.screen)
            .padding(.vertical, BifazSpacing.s)

            Button {
                editor = .new
            } label: {
                Text(kind == .client ? "tags.screen.add.client" : "tags.screen.add.project", tableName: "Tags")
            }
            .buttonStyle(.bifazPrimary)
            .accessibilityIdentifier("ui.tagAdd")
            .padding(.horizontal, BifazSpacing.screen)
            .padding(.bottom, BifazSpacing.s)

            list
        }
        .navigationTitle(Text("tags.screen.title", tableName: "Tags"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { target in
            switch target {
            case .new: TagNameSheet(kind: kind, tag: nil)
            case .rename(let tag): TagNameSheet(kind: tag.kind, tag: tag)
            }
        }
        .confirmationDialog(
            Text("tags.screen.delete.title \(pendingDeletion?.name ?? "")", tableName: "Tags"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { tag in
            Button(role: .destructive) {
                perform { try TagService.delete(tag, in: context) }
                deletions += 1
            } label: {
                Text("tags.screen.delete", tableName: "Tags")
            }
        } message: { _ in
            Text("tags.screen.delete.message", tableName: "Tags")
        }
        .alert(Text("tags.screen.error.title", tableName: "Tags"), isPresented: $saveFailed) {
            Button {} label: { Text("tags.screen.error.ok", tableName: "Tags") }
        }
        .sensoryFeedback(.warning, trigger: deletions)
        .bifazScreen()
    }

    private var list: some View {
        List {
            if active.isEmpty {
                VStack(alignment: .leading, spacing: BifazSpacing.xs) {
                    Text(kind == .client ? "tags.screen.empty.client" : "tags.screen.empty.project", tableName: "Tags")
                    Text("tags.screen.empty.note", tableName: "Tags")
                }
                .font(.bifazCaption)
                .foregroundStyle(.bifazInkSecondary)
                .listRowBackground(Color.bifazPaper)
                .listRowSeparator(.hidden)
                .listRowInsets(rowInsets)
            }
            ForEach(active) { tag in
                row(tag, archivedRow: false)
            }
            if !archived.isEmpty {
                Section {
                    if showsArchived {
                        ForEach(archived) { tag in
                            row(tag, archivedRow: true)
                        }
                    }
                } header: {
                    Button {
                        withAnimation { showsArchived.toggle() }
                    } label: {
                        HStack(spacing: BifazSpacing.xs) {
                            SectionHeader(LocalizedStringResource("tags.screen.archived", table: "Tags"))
                            Spacer(minLength: 0)
                            BifazIconView(showsArchived ? .chevronDown : .chevronRight, size: 14, relativeTo: .body)
                                .foregroundStyle(.bifazInkSecondary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityValue(Text(verbatim: "\(archived.count)"))
                    .accessibilityIdentifier("ui.tagArchivedToggle")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bifazPaper)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(
            top: BifazSpacing.xxs,
            leading: BifazSpacing.screen,
            bottom: BifazSpacing.xxs,
            trailing: BifazSpacing.screen
        )
    }

    private func row(_ tag: Tag, archivedRow: Bool) -> some View {
        let count = TagService.expenseCount(of: tag)
        return Button {
            editor = .rename(tag)
        } label: {
            HStack(spacing: BifazSpacing.m) {
                BifazIconView(tag.kind.icon, size: 20, relativeTo: .body)
                    .foregroundStyle(Color.bifazPro)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: tag.name)
                        .font(.bifazBody)
                        .foregroundStyle(.bifazInk)
                    Text("tags.screen.expenseCount \(count)", tableName: "Tags")
                        .font(.bifazCaption)
                        .foregroundStyle(.bifazInkSecondary)
                }
                Spacer(minLength: BifazSpacing.xs)
            }
            .padding(.vertical, BifazSpacing.xs)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("tags.screen.row.hint", tableName: "Tags"))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ui.tagRow")
        .listRowBackground(Color.bifazPaper)
        .listRowSeparatorTint(.bifazHairline)
        .listRowInsets(rowInsets)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeletion = tag
            } label: {
                Text("tags.screen.delete", tableName: "Tags")
            }
            Button {
                perform { try TagService.setArchived(tag, !archivedRow, in: context) }
            } label: {
                Text(archivedRow ? "tags.screen.unarchive" : "tags.screen.archive", tableName: "Tags")
            }
            .tint(.bifazInkSecondary)
            .accessibilityIdentifier(archivedRow ? "ui.tagUnarchive" : "ui.tagArchive")
        }
    }

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            Log.app.error("Saving tags failed: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            saveFailed = true
        }
    }
}

/// Sheet asking for a tag name, to create a tag or rename one; a duplicate name
/// is reported inline.
private struct TagNameSheet: View {
    let kind: TagKind
    let tag: Tag?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var duplicate = false
    @State private var saveFailed = false

    init(kind: TagKind, tag: Tag?) {
        self.kind = kind
        self.tag = tag
        _name = State(initialValue: tag?.name ?? "")
    }

    private var title: LocalizedStringResource {
        switch (tag == nil, kind) {
        case (true, .client): "tags.screen.new.client"
        case (true, .project): "tags.screen.new.project"
        case (false, .client): "tags.screen.rename.client"
        case (false, .project): "tags.screen.rename.project"
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BifazSpacing.xs) {
                SectionHeader(LocalizedStringResource("tags.screen.name", table: "Tags"))
                TextField(
                    text: $name,
                    prompt: Text("tags.screen.name.placeholder", tableName: "Tags")
                ) {
                    Text("tags.screen.name", tableName: "Tags")
                }
                .font(.bifazBody)
                .foregroundStyle(.bifazInk)
                .submitLabel(.done)
                .onSubmit(save)
                .onChange(of: name) { duplicate = false }
                .frame(minHeight: 44)
                .accessibilityIdentifier("ui.tagNameField")
                HairlineDivider()
                if duplicate {
                    HStack(alignment: .firstTextBaseline, spacing: BifazSpacing.xs) {
                        BifazIconView(.warning, size: 14, relativeTo: .footnote)
                        Text("tags.screen.duplicate", tableName: "Tags")
                    }
                    .font(.bifazCaption)
                    .foregroundStyle(.bifazError)
                    .accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, BifazSpacing.l)
            .padding(.vertical, BifazSpacing.m)
            .background(Color.bifazPaper)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("tags.screen.cancel", tableName: "Tags") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) { Text("tags.screen.save", tableName: "Tags") }
                        .disabled(!canSave)
                        .accessibilityIdentifier("ui.tagSave")
                }
            }
            .alert(Text("tags.screen.error.title", tableName: "Tags"), isPresented: $saveFailed) {
                Button {} label: { Text("tags.screen.error.ok", tableName: "Tags") }
            }
            .sensoryFeedback(.error, trigger: duplicate) { _, new in new }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.bifazPaper)
    }

    private func save() {
        guard canSave else { return }
        do {
            if let tag {
                try TagService.rename(tag, to: name, in: context)
            } else {
                try TagService.create(name, kind: kind, in: context)
            }
            dismiss()
        } catch TagService.ValidationError.duplicateName {
            duplicate = true
        } catch TagService.ValidationError.emptyName {
            // The save button is disabled for blank names.
        } catch {
            Log.app.error("Saving tag failed: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            saveFailed = true
        }
    }
}

// MARK: - Previews

private enum TagsPreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BifazStore.makeContainer(inMemory: true)
            let context = container.mainContext
            for name in ["Acme", "Globex"] { try TagService.create(name, kind: .client, in: context) }
            try TagService.create("Refonte site", kind: .project, in: context)
            let old = try TagService.create("Initech", kind: .client, in: context)
            try TagService.setArchived(old, true, in: context)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}

#Preview("Light") {
    NavigationStack { TagsView() }
        .modelContainer(TagsPreviewData.container)
}

#Preview("Dark") {
    NavigationStack { TagsView() }
        .modelContainer(TagsPreviewData.container)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    NavigationStack { TagsView() }
        .modelContainer(TagsPreviewData.container)
        .dynamicTypeSize(.accessibility3)
}
