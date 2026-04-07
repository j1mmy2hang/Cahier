import SwiftUI

@main
struct CahierApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                // 960 = sidebar(min 180) + inspector(min 260) + editor + toolbar breathing room
                .frame(minWidth: 960, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appState.noteStore.flushPendingSave()
                }
        }
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button(appState.showChatPanel ? "Hide Right Panel" : "Show Right Panel") {
                    appState.showChatPanel.toggle()
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 750)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                appState.noteStore.flushPendingSave()
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
