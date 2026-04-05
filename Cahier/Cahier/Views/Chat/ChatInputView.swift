import SwiftUI

private struct GlassInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(.separatorColor).opacity(0.3), lineWidth: 0.5)
                )
        }
    }
}

struct ChatInputView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 6) {
                TextField("Ask a question…", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .font(.body)
                    .padding(.leading, 4)
                    .padding(.top, 0)
                    .padding(.bottom, 4)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(canSend ? Color.accentColor : Color(.separatorColor))
                }
                .buttonStyle(.borderless)
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .modifier(GlassInputModifier())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.conversation.isStreaming
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        appState.conversation.appendUserMessage(text)

        guard let aiService = appState.aiService else {
            appState.conversation.appendAssistantChunk("No API key configured. Please add your OpenRouter key in Settings (Cmd+,).")
            return
        }

        appState.conversation.isStreaming = true
        appState.conversation.appendAssistantMessage()

        var messages: [(role: String, content: String)] = [
            ("system", AIService.learnSystemPrompt),
        ]

        if let context = appState.conversation.contextText {
            messages.append(("system", "The student is currently studying this French text: \"\(context)\""))
        }

        for msg in appState.conversation.messages where msg.role != .system {
            messages.append((msg.role.rawValue, msg.content))
        }

        Task {
            do {
                try await aiService.streamCompletion(messages: messages) { chunk in
                    Task { @MainActor in
                        appState.conversation.appendAssistantChunk(chunk)
                    }
                }
            } catch {
                await MainActor.run {
                    appState.conversation.appendAssistantChunk("\n\nError: \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                appState.conversation.isStreaming = false
            }
        }
    }
}
