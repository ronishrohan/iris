import Foundation
import Speech
import AVFoundation

@MainActor
final class AppleSTT: STTService {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audio = AudioEngineService()

    nonisolated func start(onPartial: @escaping @Sendable (String) -> Void,
                           onFinal: @escaping @Sendable (String) -> Void,
                           onError: @escaping @Sendable (Error) -> Void) async throws {
        try await _start(onPartial: onPartial, onFinal: onFinal, onError: onError)
    }

    nonisolated func stop() {
        Task { @MainActor in self._stop() }
    }

    private func _start(onPartial: @escaping @Sendable (String) -> Void,
                        onFinal: @escaping @Sendable (String) -> Void,
                        onError: @escaping @Sendable (Error) -> Void) async throws {
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "AppleSTT", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Recognizer unavailable"])
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        request = req

        task = recognizer.recognitionTask(with: req) { result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal { onFinal(text) } else { onPartial(text) }
            } else if let error {
                onError(error)
            }
        }

        audio.onBuffer = { [weak self] buf in
            self?.request?.append(buf)
        }
        try audio.start()
    }

    private func _stop() {
        audio.stop()
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
    }
}
