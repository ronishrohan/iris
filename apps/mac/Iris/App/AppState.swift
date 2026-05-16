import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case idle
        case thinking
        case toolCalling(name: String)
        case done
        case error(String)
    }

    var phase: Phase = .idle
    var inputText: String = ""
    var latestResponse: String = ""

    /// Previously completed responses for this session. The visible card
    /// stack shows the newest response on top with older ones peeking out
    /// behind it with a small offset.
    var pastResponses: [String] = []

    /// Bumped each time the panel should animate itself closed. The view
    /// observes this, plays the exit animation, then calls
    /// `finishClose()` so the controller can tear down the window.
    var closeRequestCounter: Int = 0

    /// Bumped each time the user submits a prompt. The view watches this
    /// to play a quick scale + brightness "pulse" so the input feels alive.
    var submitPulseCounter: Int = 0

    /// True while the panel is operating in voice mode (mic listening,
    /// TTS reply on completion).
    var voiceMode: Bool = false

    /// True while the dictation engine is actively transcribing.
    var isListening: Bool = false

    let settings = AppSettings()
    let orbController: OrbWindowController
    let hotkey = GlobalHotkey()
    let wakeWord = WakeWordEngine()
    let dictation = LiveDictation()
    private var orchestrator: ConversationOrchestrator?

    init() {
        self.orbController = OrbWindowController()
        registerHotkey()
        configureVoice()
        if settings.wakeWordEnabled {
            wakeWord.start()
        }
    }

    private func ensureOrchestrator() -> ConversationOrchestrator {
        if let orchestrator { return orchestrator }
        let o = ConversationOrchestrator(appState: self)
        orchestrator = o
        return o
    }

    private func registerHotkey() {
        hotkey.onTrigger = { [weak self] in
            Task { @MainActor in
                self?.togglePanel()
            }
        }
        hotkey.register(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)
    }

    private func configureVoice() {
        wakeWord.onWake = { [weak self] in
            Task { @MainActor in self?.handleWakeWord() }
        }
        dictation.onPartial = { [weak self] text in
            self?.inputText = text
        }
        dictation.onComplete = { [weak self] text in
            guard let self else { return }
            self.inputText = text
            self.isListening = false
            self.submit()
        }
        dictation.onError = { [weak self] _ in
            self?.isListening = false
        }
    }

    private func handleWakeWord() {
        // Already showing? Just kick dictation back on.
        if orbController.isShown && !orbController.isClosing {
            startDictation()
            return
        }
        if orbController.isShown { orbController.hide() }
        phase = .idle
        inputText = ""
        latestResponse = ""
        voiceMode = true
        orbController.show(appState: self)
        startDictation()
    }

    func toggleMic() {
        if isListening {
            voiceMode = false
            stopDictation(cancel: true)
        } else {
            voiceMode = true
            startDictation()
        }
    }

    private func startDictation() {
        // Pause wake word so we don't pick up our own input.
        wakeWord.pause()
        VoiceOut.shared.stop()
        Task { @MainActor in
            let ok = await LiveDictation.requestAuthorization()
            guard ok else {
                isListening = false
                phase = .error("Microphone or speech permission denied.")
                return
            }
            do {
                try dictation.start()
                isListening = true
            } catch {
                isListening = false
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func stopDictation(cancel: Bool) {
        if cancel { dictation.cancel() } else { dictation.stop() }
        isListening = false
        // Resume wake-word listening only if the panel is closing or
        // the user explicitly turned voice mode off.
        if !orbController.isShown || !voiceMode {
            if settings.wakeWordEnabled { wakeWord.resume() }
        }
    }

    func togglePanel() {
        // Fully closed (or mid-close): open fresh. Open & not yet closing:
        // start the close animation. This way pressing the hotkey during the
        // close animation reopens immediately instead of being swallowed.
        if orbController.isShown && !orbController.isClosing {
            requestClose()
        } else {
            // If a close animation is still in flight, abort it by tearing
            // the panel down immediately, then open a brand-new one.
            if orbController.isShown {
                orbController.hide()
            }
            phase = .idle
            inputText = ""
            latestResponse = ""
            orbController.show(appState: self)
        }
    }

    func submit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // If we were listening, stop the mic now — we have the query.
        if isListening { stopDictation(cancel: false) }
        VoiceOut.shared.stop()
        // Push the currently-visible response onto the stack BEFORE we
        // wipe latestResponse, so the previous answer stays on screen as
        // a card behind the incoming new one.
        if !latestResponse.isEmpty {
            pastResponses.append(latestResponse)
        }
        inputText = ""
        latestResponse = ""
        submitPulseCounter += 1
        let shouldSpeak = voiceMode
        Task { [weak self] in
            guard let self else { return }
            await self.ensureOrchestrator().turn(userText: trimmed)
            if shouldSpeak, !self.latestResponse.isEmpty {
                VoiceOut.shared.speak(self.latestResponse)
            }
        }
    }

    /// Called when a turn fully completes, so we can later move it onto
    /// the past-responses stack if the user starts another turn.
    func archiveCurrentResponse() {
        // No-op for now: we archive lazily at submit() time. The hook
        // exists so the orchestrator can stay decoupled.
    }

    func requestClose() {
        guard orbController.isShown, !orbController.isClosing else { return }
        orbController.isClosing = true
        closeRequestCounter += 1
    }

    /// User-intent dismissal (Esc, click outside). Ignored while we are
    /// awaiting a tool result — otherwise the permission dialogs that
    /// macOS pops on first use of Reminders / Contacts / etc. would
    /// trigger our outside-click monitor and close Iris just as the
    /// user clicks "Allow".
    func dismiss() {
        if case .toolCalling = phase { return }
        // Also block dismissals while a system modal is up (consent
        // dialogs and the like make NSApp.modalWindow non-nil).
        if NSApp.modalWindow != nil { return }
        requestClose()
    }

    func finishClose() {
        orbController.hide()
        phase = .idle
        inputText = ""
        latestResponse = ""
        pastResponses.removeAll()
        if isListening { dictation.cancel() }
        isListening = false
        voiceMode = false
        VoiceOut.shared.stop()
        if settings.wakeWordEnabled { wakeWord.resume() }
        orchestrator?.resetSession()
    }

    /// Called from Settings when the user flips the wake-word checkbox.
    func applyWakeWordSetting() {
        if settings.wakeWordEnabled {
            wakeWord.start()
        } else {
            wakeWord.stop()
        }
    }
}
