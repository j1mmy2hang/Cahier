import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        List(appState.notes, selection: $state.selectedNote) { note in
            NoteRowView(note: note)
                .tag(note)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        deleteNote(note)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        deleteNote(note)
                    }
                }
        }
        .listStyle(.sidebar)
        .navigationTitle("Notes")
        .onDeleteCommand {
            if let selected = appState.selectedNote {
                deleteNote(selected)
            }
        }
    }

    private func deleteNote(_ note: Note) {
        appState.noteStore.deleteNote(note, appState: appState)
    }
}

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
            Text(note.creationDate, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
