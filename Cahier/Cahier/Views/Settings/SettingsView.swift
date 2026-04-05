import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("openrouter-api-key") private var apiKey: String = ""
    @State private var folderPath: String = "No folder selected"
    @State private var showSaved = false

    var body: some View {
        Form {
            Section("Notes Folder") {
                HStack {
                    Text(folderPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button("Choose Folder…") {
                        pickFolder()
                    }
                }
            }

            Section("OpenRouter API Key") {
                SecureField("sk-or-v1-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveAPIKey() }

                HStack {
                    if showSaved {
                        Text("Saved!")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                    Spacer()
                    Button("Save") { saveAPIKey() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 220)
        .onAppear {
            folderPath = appState.notebookFolderURL?.path(percentEncoded: false) ?? "No folder selected"
        }
    }

    private func saveAPIKey() {
        // apiKey is already persisted via @AppStorage
        appState.loadAIService()
        withAnimation {
            showSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaved = false
            }
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
            folderPath = url.path(percentEncoded: false)
        }
    }
}
