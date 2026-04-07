import SwiftUI

@MainActor
@Observable
final class AppState {
    // Folder
    var notebookFolderURL: URL? {
        didSet {
            if let url = notebookFolderURL {
                saveBookmark(for: url)
            }
        }
    }

    // Notes
    var notes: [Note] = []
    var selectedNote: Note?

    // Selection
    var selectedText: String?
    var selectionRect: NSRect?

    // Hover
    var hoveredWord: String?
    var hoverPoint: NSPoint?

    // AI Chat
    var conversation = Conversation()
    var showChatPanel = true

    // Services
    var noteStore = NoteStore()
    var translationService = TranslationService()
    var ttsService = TTSService()
    private(set) var aiService: AIService?

    init() {
        restoreBookmark()
        loadAIService()
    }

    func loadAIService() {
        let key = UserDefaults.standard.string(forKey: "openrouter-api-key") ?? ""
        if !key.isEmpty {
            aiService = AIService(apiKey: key)
        } else {
            aiService = nil
        }
    }

    func reloadTTSService() {
        ttsService.reloadSettings()
    }

    // MARK: - Security-Scoped Bookmark

    private func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: "notebookFolderBookmark")
    }

    private func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: "notebookFolderBookmark") else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        if isStale {
            saveBookmark(for: url)
        }

        if url.startAccessingSecurityScopedResource() {
            notebookFolderURL = url
            noteStore.setFolder(url, appState: self)
        }
    }
}
