import Foundation

@MainActor
@Observable
final class VocabStore {
    var entries: [VocabEntry] = []

    private var folderURL: URL?
    private let saveDebouncer = Debouncer(delay: 0.4)

    /// JSON file lives alongside the user's notes so it rides along with any
    /// backup/sync the user has on that folder and is trivially exportable.
    /// NoteStore filters to `.md` only so this never shows as a note.
    private static let fileName = "cahier-vocab.json"
    /// Older builds wrote a dot-prefixed hidden file. Kept here only for a
    /// one-time migration on first load.
    private static let legacyHiddenFileName = ".cahier-vocab.json"

    // MARK: - Folder lifecycle

    func setFolder(_ url: URL?) {
        flushPendingSave()
        folderURL = url
        loadFromDisk()
    }

    private var fileURL: URL? {
        folderURL?.appendingPathComponent(Self.fileName)
    }

    // MARK: - Mutations

    /// Add a new entry for `text` if no equivalent (trimmed, case-insensitive)
    /// entry already exists. Returns the canonical entry either way.
    @discardableResult
    func addOrGet(text: String, sourceNoteFilename: String?) -> VocabEntry {
        let key = Self.canonicalKey(text)
        if let existing = entries.first(where: { Self.canonicalKey($0.text) == key }) {
            // Fill in a missing source if we now have one — does not overwrite
            // a manually chosen source.
            if existing.sourceNoteFilename == nil, let source = sourceNoteFilename {
                existing.sourceNoteFilename = source
                scheduleSave()
            }
            return existing
        }
        let entry = VocabEntry(
            text: text,
            sourceNoteFilename: sourceNoteFilename
        )
        entries.insert(entry, at: 0)
        scheduleSave()
        return entry
    }

    func addBlank() -> VocabEntry {
        let entry = VocabEntry(text: "")
        entries.insert(entry, at: 0)
        scheduleSave()
        return entry
    }

    func delete(_ entry: VocabEntry) {
        entries.removeAll { $0.id == entry.id }
        scheduleSave()
    }

    /// Called by views after editing a field to flush persistence.
    func markDirty() {
        scheduleSave()
    }

    /// Update `translation` on the given entry. Used when AI translation comes
    /// back asynchronously.
    func setTranslation(_ translation: String, for entry: VocabEntry) {
        entry.translation = translation
        scheduleSave()
    }

    /// Called by NoteStore when a note is renamed so source links stay valid.
    func renameSource(from oldFilename: String, to newFilename: String) {
        var changed = false
        for entry in entries where entry.sourceNoteFilename == oldFilename {
            entry.sourceNoteFilename = newFilename
            changed = true
        }
        if changed { scheduleSave() }
    }

    /// Called by NoteStore when a note is deleted so stale links clear.
    func clearSource(_ filename: String) {
        var changed = false
        for entry in entries where entry.sourceNoteFilename == filename {
            entry.sourceNoteFilename = nil
            changed = true
        }
        if changed { scheduleSave() }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveDebouncer.debounce { [weak self] in
            Task { @MainActor in self?.writeToDisk() }
        }
    }

    func flushPendingSave() {
        saveDebouncer.flush()
    }

    private func loadFromDisk() {
        guard let folderURL else { entries = []; return }
        let primary = folderURL.appendingPathComponent(Self.fileName)
        let legacy = folderURL.appendingPathComponent(Self.legacyHiddenFileName)

        // One-time migration: if only the legacy hidden file exists, promote
        // it to the visible filename so the user can see/export it.
        let fm = FileManager.default
        if !fm.fileExists(atPath: primary.path), fm.fileExists(atPath: legacy.path) {
            try? fm.moveItem(at: legacy, to: primary)
        }

        guard let data = try? Data(contentsOf: primary), !data.isEmpty else {
            entries = []
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshots = try decoder.decode([VocabEntrySnapshot].self, from: data)
            entries = snapshots
                .map(VocabEntry.init(snapshot:))
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("[VocabStore] decode failed: \(error)")
            entries = []
        }
    }

    private func writeToDisk() {
        guard let fileURL else { return }
        let snapshots = entries.map(\.snapshot)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshots)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[VocabStore] writeToDisk failed: \(error)")
        }
    }

    // MARK: - Helpers

    private static func canonicalKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
