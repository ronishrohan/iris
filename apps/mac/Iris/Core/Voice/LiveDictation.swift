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

    /// Called ~30× per second with a smoothed input amplitude in 0...1
    /// while dictation is running. Drops to 0 when stopped. The UI
    /// uses this to drive a reactive mic visualization.
    var onLevel: ((Float) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var lastTranscript: String = ""
    private(set) var isRunning = false
    /// Exponentially-smoothed amplitude, 0...1. Updated from the audio
    /// tap thread and mirrored to the main actor before invoking
    /// `onLevel`.
    private var smoothedLevel: Float = 0

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
            guard let self else { return }
            self.request?.append(buf)
            let level = Self.rmsLevel(buf)
            Task { @MainActor [weak self] in
                self?.publishLevel(level)
            }
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
        } else {
            // Even when the engine isn't reported running, force a tap
            // removal to be safe — otherwise the next engine that tries
            // to claim the input can silently fail.
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        // Replace the engine instance entirely so the underlying audio
        // unit is fully released before wake-word tries to claim it.
        audioEngine = AVAudioEngine()
        isRunning = false
        smoothedLevel = 0
        onLevel?(0)
    }

    private func publishLevel(_ raw: Float) {
        guard isRunning else { return }
        // Snappy on attack so speech onsets are felt, gentler on
        // release so the nebula doesn't pump down between syllables.
        let attack: Float = 0.45
        let release: Float = 0.10
        let coeff = raw > smoothedLevel ? attack : release
        smoothedLevel += (raw - smoothedLevel) * coeff
        onLevel?(max(0, min(1, smoothedLevel)))
    }

    /// Compute a normalized RMS level (0...1) for the buffer. The
    /// raw RMS off a vocal mic typically peaks around 0.2-0.3, so we
    /// scale up and clamp to 1 to get a useful UI range.
    private static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        let samples = channelData[0]
        var sum: Float = 0
        for i in 0..<frameLength {
            let s = samples[i]
            sum += s * s
        }
        let rms = sqrtf(sum / Float(frameLength))
        // Subtract a noise floor so ambient room hiss stays at zero.
        // Then map: ~0.25 raw RMS → ~1.0 visualized.
        let noiseFloor: Float = 0.015
        let cleaned = max(0, rms - noiseFloor)
        return min(1.0, cleaned * 4.5)
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
