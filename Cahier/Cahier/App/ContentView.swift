import SwiftUI
import Translation

struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content
                .padding(6)
                .background(.regularMaterial, in: Circle())
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var translationConfig: TranslationSession.Configuration?

    var body: some View {
        Group {
            if appState.notebookFolderURL == nil {
                welcomeView
            } else {
                mainView
            }
        }
        .translationTask(translationConfig) { session in
            await appState.translationService.setSession(session)
        }
        .task {
            await appState.translationService.prepare()
            if !appState.translationService.isReady {
                triggerTranslationDownload()
            }
        }
    }

    private var mainView: some View {
        @Bindable var bindableAppState = appState
        
        return NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            EditorView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .inspector(isPresented: $bindableAppState.showChatPanel) {
            ChatPanelView()
                .inspectorColumnWidth(min: 250, ideal: 320, max: 600)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: createNewNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New Note")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.showChatPanel.toggle()
                } label: {
                    Label("Toggle AI Tutor", systemImage: "sidebar.trailing")
                }
                .help(appState.showChatPanel ? "Hide AI Tutor" : "Show AI Tutor")
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Welcome to Cahier")
                .font(.title)
            Text("Select a folder to store your French notes.")
                .foregroundStyle(.secondary)
            Button("Choose Folder…") {
                pickFolder()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func triggerTranslationDownload() {
        translationConfig = .init(
            source: Locale.Language(identifier: "fr"),
            target: Locale.Language(identifier: "en")
        )
    }

    private func createNewNote() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        let title = "Note \(formatter.string(from: Date()))"
        if let note = appState.noteStore.createNote(title: title, appState: appState) {
            appState.selectedNote = note
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select a folder for your French notes"

        if panel.runModal() == .OK, let url = panel.url {
            appState.notebookFolderURL = url
            appState.noteStore.setFolder(url, appState: appState)
        }
    }


}
