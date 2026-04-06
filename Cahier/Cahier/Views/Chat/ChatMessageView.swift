import SwiftUI
import MarkdownUI

struct ChatMessageView: View {
    let message: Message

    var body: some View {
        if message.role == .assistant {
            Markdown(message.content)
                .markdownTextStyle { FontSize(14) }
                .lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 8) {
                if message.role == .user {
                    Spacer(minLength: 40)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Markdown(message.content)
                        .markdownTextStyle { FontSize(14) }
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .padding(10)
                        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .accentColor.opacity(0.15)
        case .assistant: return .clear
        case .system: return .clear
        }
    }
}
