import Foundation

final class AIService: Sendable {
    let apiKey: String
    private let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    static let learnSystemPrompt = """
        You are a French language tutor. The student has selected the following French text to learn. \
        If it's a word or phrase, explain its meaning with example usage. \
        If it's a sentence, break it down into parts and explain its grammar. \
        Be concise but thorough.
        """

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func streamCompletion(
        messages: [(role: String, content: String)],
        model: String = "google/gemini-3.1-flash-lite-preview",
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://cahier.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Cahier", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw AIServiceError.httpError(httpResponse.statusCode)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            if jsonString == "[DONE]" { break }

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String
            else { continue }

            onChunk(content)
        }
    }
}

enum AIServiceError: LocalizedError {
    case httpError(Int)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "API request failed with status \(code)"
        case .noAPIKey: return "No OpenRouter API key configured. Add it in Settings."
        }
    }
}
