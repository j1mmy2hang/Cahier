import SwiftUI

enum HoverLookupMode: String, CaseIterable, Identifiable {
    case automatic = "Automatic (Hover)"
    case manual = "Manual (Hold ⌘ Key)"
    var id: String { self.rawValue }
}


struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("openrouter-api-key") private var apiKey: String = ""
    @AppStorage("elevenlabs-api-key") private var elevenLabsKey: String = ""
    @AppStorage("elevenlabs-voice-id") private var elevenLabsVoiceId: String = ""
    @State private var folderPath: String = "No folder selected"
    @State private var showSaved = false
    @State private var showTTSSaved = false
    @AppStorage("hoverLookupMode") private var hoverMode: HoverLookupMode = .automatic

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

            Section("Reading Experience") {
                Picker("Dictionary Lookup", selection: $hoverMode) {
                    ForEach(HoverLookupMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
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

            Section("ElevenLabs TTS") {
                SecureField("ElevenLabs API key", text: $elevenLabsKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveTTSSettings() }

                TextField("Voice ID (default: Daniel)", text: $elevenLabsVoiceId)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveTTSSettings() }

                HStack {
                    if showTTSSaved {
                        Text("Saved!")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                    Spacer()
                    Button("Save") { saveTTSSettings() }
                        .buttonStyle(.borderedProminent)
                }

                Text("Uses eleven_turbo_v2_5 for low-latency French speech. Falls back to system TTS if no key is set. Default voice is Daniel (multilingual male).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 490)
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

    private func saveTTSSettings() {
        appState.reloadTTSService()
        withAnimation {
            showTTSSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showTTSSaved = false
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
            appState.openFolder(url)
            folderPath = url.path(percentEncoded: false)
        }
    }
}
