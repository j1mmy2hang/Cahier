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

struct ChatPanelResizeHandle: View {
    @Binding var chatPanelWidth: CGFloat
    @Binding var dragStartWidth: CGFloat
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.001))
            .frame(width: 8)
            .overlay(Divider())
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering || isDragging {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        NSCursor.resizeLeftRight.push()
                    }
                    chatPanelWidth = max(200, min(600, dragStartWidth - value.translation.width))
                }
                .onEnded { _ in
                    isDragging = false
                    dragStartWidth = chatPanelWidth
                    NSCursor.pop()
                }
            )
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var chatPanelWidth: CGFloat = 420
    @State private var dragStartWidth: CGFloat = 420

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
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 300)
        } detail: {
            HStack(spacing: 0) {
                EditorView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appState.showChatPanel {
                    ChatPanelResizeHandle(chatPanelWidth: $chatPanelWidth, dragStartWidth: $dragStartWidth)
                    ChatPanelView()
                        .frame(width: chatPanelWidth)
                        .transition(.move(edge: .trailing))
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
                    openWindow(id: "cahier-plus")
                } label: {
                    Label("Cahier Plus", systemImage: "rectangle.stack")
                }
                .help("Cahier Plus — review vocabulary")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation {
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
            appState.openFolder(url)
        }
    }
}
