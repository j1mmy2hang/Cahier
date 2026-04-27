import Foundation

@Observable
final class Conversation {
    var messages: [Message] = []
    var contextText: String?
    var paragraphContext: String?
    var isStreaming: Bool = false

    func reset(with selectedText: String, paragraph: String? = nil) {
        messages = []
        contextText = selectedText
        paragraphContext = paragraph
        isStreaming = false
    }

    func clear() {
        messages = []
        contextText = nil
        paragraphContext = nil
        isStreaming = false
    }

    func appendUserMessage(_ text: String) {
        messages.append(Message(role: .user, content: text))
    }

    func appendAssistantMessage() {
        messages.append(Message(role: .assistant, content: ""))
    }

    func appendAssistantChunk(_ chunk: String) {
        guard !messages.isEmpty, messages[messages.count - 1].role == .assistant else {
            messages.append(Message(role: .assistant, content: chunk))
            return
        }
        messages[messages.count - 1].content += chunk
    }
}
