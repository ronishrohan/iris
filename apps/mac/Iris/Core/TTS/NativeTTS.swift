import Foundation
import AVFoundation

@MainActor
final class NativeTTS: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var completion: (() -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, voiceID: String? = nil) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.completion = { cont.resume() }
            let utt = AVSpeechUtterance(string: text)
            if let voiceID, let v = AVSpeechSynthesisVoice(identifier: voiceID) {
                utt.voice = v
            } else {
                utt.voice = AVSpeechSynthesisVoice(language: "en-US")
            }
            utt.rate = AVSpeechUtteranceDefaultSpeechRate
            synth.speak(utt)
        }
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.completion?()
            self.completion = nil
        }
    }
}
