import SwiftUI

struct ChatMessageView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(backgroundColor, in: RoundedRectangle(cornerRadius: 10))
            }

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .accentColor.opacity(0.15)
        case .assistant: return Color(.unemphasizedSelectedContentBackgroundColor).opacity(0.5)
        case .system: return .clear
        }
    }
}
