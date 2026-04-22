import AVFoundation
import Foundation

@MainActor
@Observable
final class TTSService {
    private static let defaultVoiceId = "onwK4e9ZLuTAKqWW03F9" // Daniel — deep male, multilingual
    private static let model = "eleven_multilingual_v2"
    private static let cacheLimit = 80 // max cached entries

    @ObservationIgnored private(set) var apiKey = ""
    @ObservationIgnored private(set) var voiceId = defaultVoiceId

    /// The trimmed text currently being fetched from the TTS API.
    private(set) var loadingText: String?
    /// The trimmed text currently being played back.
    private(set) var playingText: String?

    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored private var speakTask: Task<Void, Never>?
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private lazy var audioDelegate = TTSAudioDelegate()
    @ObservationIgnored private lazy var speechDelegate = TTSSpeechDelegate()

    /// In-memory audio cache: same (voice, text) pair is only fetched once.
    /// Shared across all callers of this service so layer-1 Speak and the
    /// vocab table's pronunciation icon hit the same pool.
    @ObservationIgnored private var cache: [String: Data] = [:]
    @ObservationIgnored private var cacheOrder: [String] = []

    init() {
        audioDelegate.onFinish = { [weak self] in
            Task { @MainActor [weak self] in self?.handlePlaybackFinished() }
        }
        speechDelegate.onFinish = { [weak self] in
            Task { @MainActor [weak self] in self?.handlePlaybackFinished() }
        }
        synthesizer.delegate = speechDelegate
        reloadSettings()
    }

    func reloadSettings() {
        apiKey = UserDefaults.standard.string(forKey: "elevenlabs-api-key") ?? ""
        let stored = UserDefaults.standard.string(forKey: "elevenlabs-voice-id") ?? ""
        voiceId = stored.isEmpty ? Self.defaultVoiceId : stored
    }

    // MARK: - Queries (used by UI)

    func isLoading(text: String) -> Bool {
        loadingText == trim(text)
    }

    func isPlaying(text: String) -> Bool {
        playingText == trim(text)
    }

    // MARK: - Commands

    /// Start playback (always from the beginning) — stopping any current
    /// playback first.
    func speak(_ text: String) {
        let trimmed = trim(text)
        guard !trimmed.isEmpty else { return }
        stop()

        guard !apiKey.isEmpty else {
            playingText = trimmed
            speakWithSystem(trimmed)
            return
        }

        let key = cacheKey(for: trimmed)
        if let cached = cache[key] {
            playingText = trimmed
            play(cached)
            return
        }

        loadingText = trimmed
        speakTask = Task { await elevenLabsSpeak(trimmed, cacheKey: key) }
    }

    /// If currently playing the given text, stop. Otherwise start it from
    /// the beginning.
    func toggle(_ text: String) {
        let trimmed = trim(text)
        guard !trimmed.isEmpty else { return }
        if playingText == trimmed {
            stop()
        } else {
            speak(trimmed)
        }
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        loadingText = nil
        playingText = nil
    }

    // MARK: - ElevenLabs

    private func elevenLabsSpeak(_ text: String, cacheKey key: String) async {
        let escaped = voiceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? voiceId
        guard let url = URL(string:
            "https://api.elevenlabs.io/v1/text-to-speech/\(escaped)/stream"
            + "?optimize_streaming_latency=3&output_format=mp3_44100_128"
        ) else {
            loadingText = nil
            return
        }

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
                if !Task.isCancelled {
                    loadingText = nil
                    playingText = text
                    speakWithSystem(text)
                }
                return
            }
            storeCached(data, forKey: key)
            loadingText = nil
            playingText = text
            play(data)
        } catch {
            if !Task.isCancelled {
                loadingText = nil
                playingText = text
                speakWithSystem(text)
            }
        }
    }

    private func play(_ data: Data) {
        guard let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue) else {
            playingText = nil
            return
        }
        player.delegate = audioDelegate
        audioPlayer = player
        player.prepareToPlay()
        player.play()
    }

    private func handlePlaybackFinished() {
        playingText = nil
        loadingText = nil
        audioPlayer = nil
    }

    // MARK: - System fallback

    private func speakWithSystem(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
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

    // MARK: - Helpers

    private func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Delegates
//
// Kept as separate NSObject subclasses so TTSService can stay @MainActor and
// @Observable without inheriting from NSObject (which would interfere with
// the observation macro and Swift 6 concurrency).

final class TTSAudioDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    var onFinish: (@Sendable () -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        onFinish?()
    }
}

final class TTSSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (@Sendable () -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
