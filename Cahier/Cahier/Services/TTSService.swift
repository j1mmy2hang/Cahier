import AVFoundation

final class TTSService {
    private let synthesizer = AVSpeechSynthesizer()
    private let frenchVoice = AVSpeechSynthesisVoice(language: "fr-FR")

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = frenchVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
