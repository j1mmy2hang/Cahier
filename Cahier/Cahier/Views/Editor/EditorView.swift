import SwiftUI

struct EditorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let note = appState.selectedNote {
                NotePageView(
                    note: note,
                    onTextChange: { newText in
                        note.content = newText
                        appState.noteStore.saveNote(note)
                    },
                    onTitleCommit: { newTitle in
                        _ = appState.noteStore.renameNote(note, newTitle: newTitle, appState: appState)
                    },
                    onSelectionChange: { text, rect in
                        appState.selectedText = text
                        appState.selectionRect = rect
                    },
                    onHoverWord: { word, point in
                        appState.hoveredWord = word
                        appState.hoverPoint = point
                    },
                    translationService: appState.translationService,
                    ttsService: appState.ttsService,
                    appState: appState
                )
                // Use the Note's object identity so that renaming (which changes
                // fileURL) does NOT tear down the text view and lose state.
                .id(ObjectIdentifier(note))
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
