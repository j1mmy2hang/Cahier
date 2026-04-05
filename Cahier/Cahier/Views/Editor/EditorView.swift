import SwiftUI

struct EditorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let note = appState.selectedNote {
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
