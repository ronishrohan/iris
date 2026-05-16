import Foundation
import AVFoundation
import Speech

/// Continuous on-device speech recognition that streams partial
/// transcripts to a callback while the user dictates, then auto-fires
/// `onComplete` once silence is detected (~1.2s with no new words).
///
/// The caller is responsible for requesting the necessary permissions
/// via `requestAuthorization()` before starting.
@MainActor
final class LiveDictation: NSObject {
    /// Called every time the transcript grows. Always the FULL latest
    /// transcript, not a delta — easier for the UI to mirror.
    var onPartial: ((String) -> Void)?

    /// Called once when the user stops speaking long enough to count as
    /// "done". Passes the final transcript. Caller decides whether to
    /// submit it.
    var onComplete: ((String) -> Void)?

    /// Called if recognition fails or is interrupted. Always followed
    /// by an internal stop so callers can simply reset their UI.
    var onError: ((Error) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var lastTranscript: String = ""
    private(set) var isRunning = false

    /// Silence window (seconds) after which we treat the user as done.
    var silenceTimeout: TimeInterval = 1.2

    override init() {
        super.init()
    }

    /// Ask the user for both Speech and Microphone permissions. Safe to
    /// call repeatedly; macOS will only prompt once per app install.
    static func requestAuthorization() async -> Bool {
        let speechOK: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micOK = await AVCaptureDevice.requestAccess(for: .audio)
        return speechOK && micOK
    }

    func start() throws {
        guard !isRunning else { return }
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "LiveDictation", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available."])
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(macOS 10.15, *) {
            req.requiresOnDeviceRecognition = true
        }
        self.request = req
        self.lastTranscript = ""

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    if text != self.lastTranscript {
                        self.lastTranscript = text
                        self.onPartial?(text)
                        self.resetSilenceTimer()
                    }
                    if result.isFinal {
                        self.finishWithCurrentTranscript()
                    }
                }
                if let error {
                    self.onError?(error)
                    self.stop()
                }
            }
        }
    }

    func stop() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRunning = false
    }

    /// Stop without firing `onComplete`. Used when the user cancels.
    func cancel() {
        let wasRunning = isRunning
        stop()
        _ = wasRunning
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishWithCurrentTranscript()
            }
        }
    }

    private func finishWithCurrentTranscript() {
        let final = lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        guard !final.isEmpty else { return }
        onComplete?(final)
    }
}
