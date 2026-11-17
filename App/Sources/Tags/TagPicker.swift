import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

extension TagKind {
    var icon: BifazIcon {
        switch self {
        case .client: .services
        case .project: .note
        }
    }
}

/// Chooses the client or the project of a Pro expense or rule: a chip that opens
/// a menu with the active tags, "None" and "New…" (quick creation).
struct TagPicker: View {
    let kind: TagKind
    @Binding var selection: Tag?

    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var isCreating = false
    @State private var newName = ""

    private var tags: [Tag] { allTags.filter { $0.kind == kind && !$0.isArchived } }

    private var placeholder: LocalizedStringResource {
        kind == .client ? "tags.picker.addClient" : "tags.picker.addProject"
    }

    var body: some View {
        Menu {
            if selection != nil {
                Button("tags.picker.none") { selection = nil }
                Divider()
            }
            ForEach(tags) { tag in
                Button {
                    selection = tag
                } label: {
                    if selection?.id == tag.id {
                        Label { Text(verbatim: tag.name) } icon: { BifazIcon.check.image }
                    } else {
                        Text(verbatim: tag.name)
                    }
                }
            }
            Divider()
            Button {
                newName = ""
                isCreating = true
            } label: {
                Text(kind == .client ? "tags.picker.newClient" : "tags.picker.newProject")
            }
        } label: {
            ChipLabel(
                title: selection.map { Text(verbatim: $0.name) } ?? Text(placeholder),
                icon: kind.icon,
                symbolTint: .bifazPro,
                isSelected: selection != nil
            )
        }
        .menuOrder(.fixed)
        .accessibilityIdentifier(kind == .client ? "ui.tagPickerClient" : "ui.tagPickerProject")
        .alert(kind == .client ? "tags.picker.newClient" : "tags.picker.newProject", isPresented: $isCreating) {
            TextField(text: $newName) { Text("tags.picker.name") }
                .accessibilityIdentifier("ui.tagNewName")
            Button("tags.picker.create") {
                if let tag = try? TagService.create(newName, kind: kind, in: context) { selection = tag }
            }
            .accessibilityIdentifier("ui.tagCreate")
            Button("tags.picker.cancel", role: .cancel) {}
        }
    }
}
