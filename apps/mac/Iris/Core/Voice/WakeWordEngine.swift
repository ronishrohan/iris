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
///   - Each `startTask()` increments a generation counter, and the
///     SFSpeechRecognitionTask callback ignores results from any
///     older generation. This avoids zombie callbacks from a cancelled
///     task tearing down the new one during a stop/start cycle.
@MainActor
final class WakeWordEngine: NSObject {
    var onWake: (() -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var restartTimer: Timer?
    private var cooldownUntil: Date = .distantPast
    private var generation: Int = 0
    private(set) var isRunning = false

    private let wakeVariants: [String] = [
        "hey iris",
        "hi iris",
        "hey, iris",
        "hello iris"
    ]

    func start() {
        Task { @MainActor in
            let ok = await LiveDictation.requestAuthorization()
            guard ok, let recognizer, recognizer.isAvailable else { return }
            await self.startInternal(attempt: 0)
            _ = recognizer
        }
    }

    private func startInternal(attempt: Int) async {
        // Always rebuild from scratch — a stale audio engine from a
        // previous stop() can otherwise prevent the new one from
        // claiming the input.
        tearDown()
        audioEngine = AVAudioEngine()
        beginEngine()
        // If the audio engine failed to start (mic still held by
        // another engine), retry up to 3 times with backoff.
        if !audioEngine.isRunning, attempt < 3 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await startInternal(attempt: attempt + 1)
            return
        }
        guard audioEngine.isRunning else { return }
        startTask()
        scheduleRestart()
        isRunning = true
    }

    func stop() {
        isRunning = false
        tearDown()
    }

    func pause() { stop() }
    func resume() { start() }

    private func tearDown() {
        generation += 1                    // invalidate any in-flight callbacks
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
    }

    private func beginEngine() {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        // safety: in case a tap somehow survived a crash on a prior run
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            // mic is unavailable — silently no-op; next start() may succeed
        }
    }

    private func startTask() {
        guard let recognizer else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(macOS 10.15, *) {
            req.requiresOnDeviceRecognition = true
        }
        self.request = req

        let myGen = generation
        self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                // Drop stale callbacks from previous task generations.
                guard myGen == self.generation else { return }
                if let result {
                    let text = result.bestTranscription.formattedString.lowercased()
                    if Date() >= self.cooldownUntil, self.containsWakePhrase(text) {
                        self.cooldownUntil = Date().addingTimeInterval(2.0)
                        self.onWake?()
                    }
                }
                if error != nil {
                    // Most errors are benign (silence timeouts, mic glitches).
                    // Roll the task only if we're still supposed to be running.
                    if self.isRunning { self.rollTask() }
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
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.rollTask()
            }
        }
    }

    /// Cancel the current recognition task and start a fresh one without
    /// touching the audio engine. Used by the 45s rotation timer and on
    /// recoverable SF errors.
    private func rollTask() {
        generation += 1
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        guard isRunning else { return }
        startTask()
    }
}
