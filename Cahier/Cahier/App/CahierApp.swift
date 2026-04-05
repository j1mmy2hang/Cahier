import SwiftUI

@main
struct CahierApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appState.noteStore.flushPendingSave()
                }
        }
        .windowStyle(.titleBar)
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
