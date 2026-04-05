import Foundation
import NaturalLanguage
@preconcurrency import Translation

@MainActor
final class TranslationService {
    private var session: TranslationSession?
    private(set) var isReady = false
    private var isPreparing = false

    init() {
        NLTagger.requestAssets(for: .french, tagScheme: .lemma) { _, _ in }
    }

    /// Called from .translationTask modifier to receive a session
    func setSession(_ session: TranslationSession) {
        self.session = session
        self.isReady = true
    }

    /// Prepare translation — download models if needed, then create session
    func prepare() async {
        guard !isReady, !isPreparing else { return }
        isPreparing = true

        if #available(macOS 26.0, *) {
            // Try direct init for already-installed language pair
            if let s = try? TranslationSession(
                installedSource: Locale.Language(identifier: "fr"),
                target: Locale.Language(identifier: "en")
            ) {
                session = s
                isReady = true
                isPreparing = false
                return
            }
        }

        // Fallback: session will be provided via .translationTask modifier in ContentView
        isPreparing = false
    }

    func translateWord(_ word: String) async -> TranslationResult? {
        if !isReady {
            await prepare()
        }
        guard let session else { return nil }

        let lemma = extractLemma(word)
        do {
            let response = try await session.translate(lemma)
            return TranslationResult(
                originalWord: word,
                lemma: lemma,
                translation: response.targetText
            )
        } catch {
            return nil
        }
    }

    private nonisolated func extractLemma(_ word: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        let range = word.startIndex..<word.endIndex
        tagger.setLanguage(.french, range: range)
        if let (tag, _) = tagger.tags(in: range, unit: .word, scheme: .lemma, options: [.omitWhitespace, .omitPunctuation]).first,
           let tag {
            return tag.rawValue
        }
        return word
    }
}

struct TranslationResult: Sendable {
    let originalWord: String
    let lemma: String
    let translation: String
}
