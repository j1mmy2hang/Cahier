import SwiftUI

struct EditorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let note = appState.selectedNote {
                VStack(spacing: 0) {
                    NoteTitleEditor(note: note)

                    Divider()
                        .padding(.horizontal, 40)
                        .padding(.bottom, 18)
                        .opacity(0.5)

                    MarkdownTextView(
                        note: note,
                        onTextChange: { newText in
                            note.content = newText
                            appState.noteStore.saveNote(note)
                        },
                        onSelectionChange: { text, rect in
                            let oldText = appState.selectedText
                            appState.selectedText = text
                            appState.selectionRect = rect
                            if let text, text != oldText, text != appState.conversation.contextText {
                                // Don't auto-reset; only reset when Learn is pressed
                            }
                        },
                        onHoverWord: { word, point in
                            appState.hoveredWord = word
                            appState.hoverPoint = point
                        },
                        translationService: appState.translationService,
                        ttsService: appState.ttsService,
                        appState: appState
                    )
                    // Force a completely fresh NSTextView when switching notes
                    .id(note.fileURL)
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Select or create a note")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct NoteTitleEditor: View {
    @Environment(AppState.self) private var appState
    let note: Note
    @State private var localTitle: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField("Note Title", text: $localTitle)
            .textFieldStyle(.plain)
            .font(.system(size: 26, weight: .semibold, design: .serif))
            .focused($isFocused)
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 10)
            .onChange(of: note.title) { _, newTitle in
                if !isFocused {
                    localTitle = newTitle
                }
            }
            .onChange(of: isFocused) { _, isNowFocused in
                if !isNowFocused {
                    commitRename()
                }
            }
            .onSubmit {
                commitRename()
            }
            .task {
                localTitle = note.title
            }
    }
    
    private func commitRename() {
        let trimmed = localTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != note.title else {
            localTitle = note.title // Revert if empty or unchanged
            return
        }
        
        let success = appState.noteStore.renameNote(note, newTitle: trimmed, appState: appState)
        if !success {
            // Revert on failure (e.g., file already exists or invalid name)
            localTitle = note.title
        }
    }
}
