import Foundation

final class AIService: Sendable {
    let apiKey: String
    private let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    static let learnSystemPrompt = """
        You are a French language tutor. The student has selected the following French text to learn. \
        If it's a word or phrase, explain its meaning with example usage. \
        If it's a sentence, first translate, and then break it down into parts and explain its grammar. \
        Be as concise as possible. Start directly with no introduction. Use English for explanation. 
        """

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// One-shot translation of French text to English. Intentionally returns a
    /// single clean line — no quotes, labels, or alternatives — so it can be
    /// written straight into the vocab table.
    func translate(
        text: String,
        model: String = "google/gemini-3.1-flash-lite-preview"
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://cahier.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Cahier", forHTTPHeaderField: "X-Title")

        let systemPrompt = """
            Translate the given French text to English. Reply with ONLY the English translation — \
            no quotes, no labels, no alternatives, no commentary. For a single word, give the most \
            common meaning. Keep sentence translations faithful and natural. Output a single line.
            """

        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AIServiceError.httpError(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AIServiceError.badResponse
        }

        return Self.sanitizeTranslation(content)
    }

    private static func sanitizeTranslation(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip leading/trailing wrapping quotes the model sometimes adds.
        let quoteChars: Set<Character> = ["\"", "'", "“", "”", "‘", "’", "«", "»"]
        while let first = s.first, quoteChars.contains(first) { s.removeFirst() }
        while let last = s.last, quoteChars.contains(last) { s.removeLast() }
        // Some models prefix with "Translation:" or similar.
        let prefixes = ["Translation:", "translation:", "English:", "english:"]
        for prefix in prefixes where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
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
    case badResponse

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "API request failed with status \(code)"
        case .noAPIKey: return "No OpenRouter API key configured. Add it in Settings."
        case .badResponse: return "Unexpected response shape from API."
        }
    }
}
