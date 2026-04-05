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
    @State private var chatWidth: CGFloat = 320
    @GestureState private var isDragging = false

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
        NavigationSplitView {
            SidebarView()
        } detail: {
            HStack(spacing: 0) {
                EditorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appState.showChatPanel {
                    ZStack(alignment: .leading) {
                        Divider()
                            .frame(width: 1)
                        
                        // Transparent draggable area for resize
                        Color.clear
                            .frame(width: 5)
                            .contentShape(Rectangle())
                            .onHover { inside in
                                if inside { NSCursor.resizeLeftRight.push() }
                                else { NSCursor.pop() }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .updating($isDragging) { _, state, _ in
                                        state = true
                                    }
                                    .onChanged { value in
                                        let newWidth = chatWidth - value.translation.width
                                        chatWidth = max(250, min(newWidth, 600))
                                    }
                            )
                    }
                    .zIndex(1)

                    ChatPanelView()
                        .frame(width: chatWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
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
                    withAnimation(.easeInOut(duration: 0.25)) {
                        appState.showChatPanel.toggle()
                    }
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
