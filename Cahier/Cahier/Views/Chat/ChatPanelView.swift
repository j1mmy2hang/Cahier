import SwiftUI

struct ChatPanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with clear button — always visible
            HStack {
                Button(action: { appState.conversation.clear() }) {
                    Label("Clear Chat", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Clear conversation")
                .disabled(appState.conversation.messages.isEmpty)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if appState.conversation.messages.isEmpty {
                chatEmptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(appState.conversation.messages) { message in
                                ChatMessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: appState.conversation.messages.count) {
                        if let last = appState.conversation.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            ChatInputView()
        }
        .background(.clear)
    }

    private var chatEmptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("Select text and press Learn,\nor ask a question below.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
