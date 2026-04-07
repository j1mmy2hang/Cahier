import AVFoundation
import Foundation

@MainActor
final class TTSService {
    private static let defaultVoiceId = "onwK4e9ZLuTAKqWW03F9" // Daniel — deep male, multilingual
    private static let model = "eleven_multilingual_v2"
    private static let cacheLimit = 80 // max cached entries

    private(set) var apiKey = ""
    private(set) var voiceId = defaultVoiceId

    private var audioPlayer: AVAudioPlayer?
    private var speakTask: Task<Void, Never>?
    private let synthesizer = AVSpeechSynthesizer()

    /// In-memory audio cache: same (voice, text) pair is only fetched once.
    private var cache: [String: Data] = [:]
    private var cacheOrder: [String] = []

    init() { reloadSettings() }

    func reloadSettings() {
        apiKey = UserDefaults.standard.string(forKey: "elevenlabs-api-key") ?? ""
        let stored = UserDefaults.standard.string(forKey: "elevenlabs-voice-id") ?? ""
        voiceId = stored.isEmpty ? Self.defaultVoiceId : stored
    }

    func speak(_ text: String) {
        stop()
        guard !apiKey.isEmpty else { return speakWithSystem(text) }

        let key = cacheKey(for: text)
        if let cached = cache[key] {
            play(cached)
            return
        }

        speakTask = Task { await elevenLabsSpeak(text, cacheKey: key) }
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - ElevenLabs

    private func elevenLabsSpeak(_ text: String, cacheKey key: String) async {
        let escaped = voiceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? voiceId
        guard let url = URL(string:
            "https://api.elevenlabs.io/v1/text-to-speech/\(escaped)/stream"
            + "?optimize_streaming_latency=3&output_format=mp3_44100_128"
        ) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": Self.model,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ] as [String: Any])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  !data.isEmpty
            else {
                if !Task.isCancelled { speakWithSystem(text) }
                return
            }
            storeCached(data, forKey: key)
            play(data)
        } catch {
            if !Task.isCancelled { speakWithSystem(text) }
        }
    }

    private func play(_ data: Data) {
        guard let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue)
        else { return }
        audioPlayer = player
        player.prepareToPlay()
        player.play()
    }

    // MARK: - Cache

    private func cacheKey(for text: String) -> String {
        "\(voiceId):\(text)"
    }

    private func storeCached(_ data: Data, forKey key: String) {
        cache[key] = data
        cacheOrder.append(key)
        while cacheOrder.count > Self.cacheLimit {
            let evicted = cacheOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }

    // MARK: - System fallback

    private func speakWithSystem(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }
}
