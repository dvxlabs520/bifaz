import Foundation
import SwiftData

/// Client and project tags (Pro only, phase 4). A Pro expense carries at most
/// one client and one project. Deleting a tag never deletes expenses; archiving
/// keeps it on its expenses but stops offering it.
public enum TagService {
    public enum ValidationError: Error, Equatable, Sendable {
        case emptyName
        case duplicateName
    }

    /// Active tags of a kind, by name.
    @MainActor
    public static func tags(_ kind: TagKind, includingArchived: Bool = false, in context: ModelContext) throws -> [Tag] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.kindRawValue == raw },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor).filter { includingArchived || !$0.isArchived }
    }

    /// Creates a tag, or returns the existing one with the same name (case and
    /// accents ignored), unarchiving it.
    @discardableResult
    public static func create(_ name: String, kind: TagKind, in context: ModelContext) throws -> Tag {
        let name = normalized(name)
        guard !name.isEmpty else { throw ValidationError.emptyName }
        if let existing = try existing(named: name, kind: kind, in: context) {
            existing.isArchived = false
            try context.save()
            return existing
        }
        let tag = Tag(name: name, kind: kind)
        context.insert(tag)
        try context.save()
        return tag
    }

    public static func rename(_ tag: Tag, to name: String, in context: ModelContext) throws {
        let name = normalized(name)
        guard !name.isEmpty else { throw ValidationError.emptyName }
        if let existing = try existing(named: name, kind: tag.kind, in: context), existing.id != tag.id {
            throw ValidationError.duplicateName
        }
        tag.name = name
        try context.save()
    }

    public static func setArchived(_ tag: Tag, _ archived: Bool, in context: ModelContext) throws {
        tag.isArchived = archived
        try context.save()
    }

    /// Deletes the tag; its expenses, rules and merchant memories just lose it.
    public static func delete(_ tag: Tag, in context: ModelContext) throws {
        context.delete(tag)
        try context.save()
    }

    /// How many expenses carry the tag (for the delete confirmation).
    public static func expenseCount(of tag: Tag) -> Int { tag.expenses?.count ?? 0 }

    static func normalized(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func existing(named name: String, kind: TagKind, in context: ModelContext) throws -> Tag? {
        let key = MerchantRule.key(for: name)
        let raw = kind.rawValue
        return try context.fetch(FetchDescriptor<Tag>(predicate: #Predicate { $0.kindRawValue == raw }))
            .first { MerchantRule.key(for: $0.name) == key }
    }
}
