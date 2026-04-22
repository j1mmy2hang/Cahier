import Foundation

@Observable
final class VocabEntry: Identifiable {
    let id: UUID
    var text: String
    var translation: String
    /// Filename of the source note (e.g. "Note 2025-04-10.md"). `nil` when the
    /// entry has no source (manually added rows, or a deleted note).
    var sourceNoteFilename: String?
    /// Free-text note the user can write about this entry.
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        translation: String = "",
        sourceNoteFilename: String? = nil,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.translation = translation
        self.sourceNoteFilename = sourceNoteFilename
        self.note = note
        self.createdAt = createdAt
    }
}

/// Plain value snapshot used for JSON persistence. `note` is optional on
/// decode so older files (written before the column existed) still load.
struct VocabEntrySnapshot: Codable {
    let id: UUID
    let text: String
    let translation: String
    let sourceNoteFilename: String?
    let note: String?
    let createdAt: Date
}

extension VocabEntry {
    var snapshot: VocabEntrySnapshot {
        VocabEntrySnapshot(
            id: id,
            text: text,
            translation: translation,
            sourceNoteFilename: sourceNoteFilename,
            note: note,
            createdAt: createdAt
        )
    }

    convenience init(snapshot s: VocabEntrySnapshot) {
        self.init(
            id: s.id,
            text: s.text,
            translation: s.translation,
            sourceNoteFilename: s.sourceNoteFilename,
            note: s.note ?? "",
            createdAt: s.createdAt
        )
    }
}
