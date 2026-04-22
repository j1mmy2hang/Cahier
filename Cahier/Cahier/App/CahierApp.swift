import SwiftUI

@main
struct CahierApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        Window("Cahier", id: "main") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 960, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appState.noteStore.flushPendingSave()
                    appState.vocabStore.flushPendingSave()
                }
        }
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button(appState.showChatPanel ? "Hide Right Panel" : "Show Right Panel") {
                    withAnimation {
                        appState.showChatPanel.toggle()
                    }
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
                appState.vocabStore.flushPendingSave()
            }
        }

        Window("Cahier Plus", id: "cahier-plus") {
            CahierPlusView()
                .environment(appState)
                .frame(minWidth: 720, minHeight: 480)
                .containerBackground(.ultraThickMaterial, for: .window)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 660)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
