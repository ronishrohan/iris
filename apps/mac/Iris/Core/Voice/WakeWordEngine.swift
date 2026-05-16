import Foundation
import AVFoundation
import Speech

/// Continuously listens for "hey iris" on the system mic using
/// on-device `SFSpeechRecognizer`. When the phrase is detected, fires
/// `onWake` on the main actor. The caller is expected to open the
/// panel in voice mode in response.
///
/// Implementation notes:
///   - SFSpeechRecognizer tasks have a ~60s soft limit. We restart the
///     task every ~45s to stay well under it.
///   - Audio is tapped from a single AVAudioEngine input node that we
///     keep running across task restarts to avoid clicks.
///   - To suppress repeat triggers from the same "hey iris" hanging
///     around in the transcript, we set a 2s cooldown after each fire.
@MainActor
final class WakeWordEngine: NSObject {
    var onWake: (() -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var restartTimer: Timer?
    private var cooldownUntil: Date = .distantPast
    private(set) var isRunning = false

    /// Phrases that count as wake words. Order matters only for early-out.
    private let wakeVariants: [String] = [
        "hey iris",
        "hi iris",
        "hey, iris",
        "hello iris"
    ]

    func start() {
        guard !isRunning else { return }
        Task { @MainActor in
            let ok = await LiveDictation.requestAuthorization()
            guard ok, let recognizer, recognizer.isAvailable else { return }
            self.beginEngine()
            self.startTask()
            self.scheduleRestart()
            self.isRunning = true
        }
    }

    func stop() {
        restartTimer?.invalidate()
        restartTimer = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        isRunning = false
    }

    /// Temporarily suspend listening — used while the panel is open in
    /// voice mode so the wake-word engine and live dictation don't
    /// fight over the mic.
    func pause() { stop() }

    /// Resume listening after a `pause()`.
    func resume() { start() }

    private func beginEngine() {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { /* if mic is busy we just no-op */ }
    }

    private func startTask() {
        guard let recognizer else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(macOS 10.15, *) {
            req.requiresOnDeviceRecognition = true
        }
        self.request = req
        self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString.lowercased()
                    if Date() >= self.cooldownUntil, self.containsWakePhrase(text) {
                        self.cooldownUntil = Date().addingTimeInterval(2.0)
                        self.onWake?()
                        // Roll the recognizer so the matched text doesn't
                        // keep firing on subsequent partials.
                        self.restartTask()
                    }
                }
                if error != nil {
                    // Most errors are benign (timeouts, mic glitches).
                    // Just roll the task.
                    self.restartTask()
                }
            }
        }
    }

    private func containsWakePhrase(_ text: String) -> Bool {
        for v in wakeVariants where text.contains(v) { return true }
        return false
    }

    private func scheduleRestart() {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.restartTask() }
        }
    }

    private func restartTask() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        guard isRunning || audioEngine.isRunning else { return }
        startTask()
    }
}
