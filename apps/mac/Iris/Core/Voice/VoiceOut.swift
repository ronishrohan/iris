import Foundation
import AVFoundation

/// Lightweight wrapper around `AVSpeechSynthesizer` for Iris's TTS replies.
/// We keep one synthesizer instance for the lifetime of the app so we
/// can cancel mid-sentence cleanly when the panel closes or the user
/// starts another turn.
@MainActor
final class VoiceOut {
    static let shared = VoiceOut()

    private let synth = AVSpeechSynthesizer()
    private var preferredVoice: AVSpeechSynthesisVoice? = {
        // Prefer a high-quality "enhanced/premium" English voice if the
        // user has one installed; fall back to the system default.
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { v in
            v.language.hasPrefix("en")
        }
        return candidates.first(where: { $0.quality == .premium })
            ?? candidates.first(where: { $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    private init() {}

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        let utterance = AVSpeechUtterance(string: trimmed)
        if let v = preferredVoice { utterance.voice = v }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
    }
}
