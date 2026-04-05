import Foundation

@MainActor
@Observable
final class NoteStore {
    private var folderURL: URL?
    private var streamRef: FSEventStreamRef?
    private weak var currentAppState: AppState?
    private let saveDebouncer = Debouncer(delay: 0.5)

    func setFolder(_ url: URL, appState: AppState) {
        stopWatching()
        folderURL = url
        loadAllNotes(into: appState)
        startWatching(appState: appState)
    }

    // MARK: - CRUD

    func createNote(title: String, appState: AppState) -> Note? {
        guard let folderURL else {
            print("[NoteStore] createNote failed: no folderURL")
            return nil
        }
        let sanitized = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
        let fileURL = folderURL.appendingPathComponent("\(sanitized).md")

        let content = "# \(title)\n\n"

        // Set the note content

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("[NoteStore] createNote write failed: \(error)")
            return nil
        }

        let note = Note(
            fileURL: fileURL,
            content: content,
            creationDate: Date(),
            modificationDate: Date()
        )
        appState.notes.insert(note, at: 0)
        return note
    }

    func deleteNote(_ note: Note, appState: AppState) {
        // Flush any pending save for this note
        flushPendingSave()

        // Select an adjacent note before removing
        if appState.selectedNote == note {
            if let index = appState.notes.firstIndex(of: note) {
                if appState.notes.count > 1 {
                    // Prefer the next note, fall back to previous
                    let adjacentIndex = index + 1 < appState.notes.count ? index + 1 : index - 1
                    appState.selectedNote = appState.notes[adjacentIndex]
                } else {
                    appState.selectedNote = nil
                }
            } else {
                appState.selectedNote = nil
            }
        }

        appState.notes.removeAll { $0 == note }

        try? FileManager.default.removeItem(at: note.fileURL)
    }

    func saveNote(_ note: Note) {
        note.isDirty = true
        saveDebouncer.debounce { [weak self] in
            self?.writeToDisk(note)
        }
    }

    /// Immediately write any pending debounced save.
    func flushPendingSave() {
        saveDebouncer.flush()
    }

    private func writeToDisk(_ note: Note) {
        do {
            try note.content.write(to: note.fileURL, atomically: true, encoding: .utf8)
            let values = try? note.fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            if let diskDate = values?.contentModificationDate {
                note.modificationDate = diskDate
            } else {
                note.modificationDate = Date()
            }
            note.isDirty = false
        } catch {
            print("[NoteStore] writeToDisk failed: \(error)")
        }
    }

    // MARK: - Load

    private func loadAllNotes(into appState: AppState) {
        guard let folderURL else { return }
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let mdFiles = urls.filter { $0.pathExtension == "md" }
        var notes: [Note] = []
        for url in mdFiles {
            if let note = loadNote(from: url) {
                notes.append(note)
            }
        }
        notes.sort { $0.creationDate > $1.creationDate }
        appState.notes = notes
    }

    private func loadNote(from url: URL) -> Note? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return Note(
            fileURL: url,
            content: content,
            creationDate: values?.creationDate ?? Date(),
            modificationDate: values?.contentModificationDate ?? Date()
        )
    }

    // MARK: - File Watching

    private func startWatching(appState: AppState) {
        self.currentAppState = appState
        guard let folderURL else { return }

        let pathsToWatch = [folderURL.path] as CFArray
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let mySelf = Unmanaged<NoteStore>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            
            DispatchQueue.main.async {
                guard let appState = mySelf.currentAppState else { return }
                MainActor.assumeIsolated {
                    mySelf.handleDirectoryChange(appState: appState)
                }
            }
        }

        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventsGetCurrentEventId(),
            1.0, // 1 second latency
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        streamRef = stream
        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
            FSEventStreamStart(stream)
        }
    }

    private func stopWatching() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
        }
    }

    private func handleDirectoryChange(appState: AppState) {
        guard let folderURL else { return }
        let fm = FileManager.default

        guard let currentFiles = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let diskMDFiles = Set(currentFiles.filter { $0.pathExtension == "md" })
        let existingURLs = Set(appState.notes.map(\.fileURL))

        // New files on disk that we don't have in memory (skip our own recent creates)
        for url in diskMDFiles.subtracting(existingURLs) {
            if let note = loadNote(from: url) {
                appState.notes.append(note)
            }
        }

        // Files deleted from disk that we still have in memory (skip our own recent deletes)
        for url in existingURLs.subtracting(diskMDFiles) {
            if appState.selectedNote?.fileURL == url {
                appState.selectedNote = nil
            }
            appState.notes.removeAll { $0.fileURL == url }
        }

        // Modified files on disk (skip our own recent saves and dirty notes)
        for note in appState.notes {
            guard !note.isDirty else { continue }
            let values = try? note.fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let diskDate = values?.contentModificationDate ?? .distantPast
            if diskDate > note.modificationDate {
                if let content = try? String(contentsOf: note.fileURL, encoding: .utf8) {
                    note.content = content
                    note.modificationDate = diskDate
                }
            }
        }

        appState.notes.sort { $0.creationDate > $1.creationDate }
    }
}
