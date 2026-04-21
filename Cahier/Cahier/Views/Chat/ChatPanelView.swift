import SwiftUI

struct ChatPanelView: View {
    @Environment(AppState.self) private var appState

    /// Tracks whether the bottom of the chat is visible in the viewport.
    /// Driven by onAppear/onDisappear of an invisible anchor at the end of the list.
    /// When true, streaming content auto-scrolls; when the user scrolls up, it turns
    /// false and we stop pulling them back down.
    @State private var isNearBottom = true


    var body: some View {
        VStack(spacing: 0) {
            if appState.conversation.messages.isEmpty {
                chatEmptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(appState.conversation.messages) { message in
                                if message.role != .assistant || !message.content.isEmpty {
                                    ChatMessageView(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)

                        // Anchor sits outside the LazyVStack so it doesn't inherit
                        // the 16pt inter-item spacing or cause layout flicker.
                        Color.clear
                            .frame(height: 64)
                            .id("bottom")
                            .onAppear { isNearBottom = true }
                            .onDisappear { isNearBottom = false }
                    }
                    .onChange(of: appState.conversation.messages.count) {
                        // When a new user message is submitted, scroll it to the top of the viewport
                        // and re-enable auto-scroll so streaming follows.
                        let messages = appState.conversation.messages
                        guard let lastUser = messages.last(where: { $0.role == .user }),
                              let idx = messages.lastIndex(where: { $0.id == lastUser.id }),
                              idx >= messages.count - 2 else { return }

                        isNearBottom = true
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            proxy.scrollTo(lastUser.id, anchor: .top)
                        }
                    }
                    .onChange(of: appState.conversation.messages.last?.content) {
                        // During streaming, follow the bottom — but only if the user hasn't scrolled away.
                        guard isNearBottom, appState.conversation.isStreaming else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
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
