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

    /// Structured per-task payload for the most-recent tool call, if it
    /// emitted one. Drives the rich response cards (reminders, timer,
    /// calendar, weather, etc.). Cleared at the start of every turn.
    var latestResponseCard: ToolUIResult? = nil

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

    /// Smoothed live mic amplitude in 0...1 while the dictation engine
    /// is running. Drives the reactive nebula speed in the input pill.
    var micAmplitude: Float = 0

    let settings = AppSettings()
    let orbController: OrbWindowController
    let hotkey = GlobalHotkey()
    let doubleTap = DoubleTapModifier()
    let wakeWord = WakeWordEngine()
    let dictation = LiveDictation()
    private var orchestrator: ConversationOrchestrator?

    init() {
        self.orbController = OrbWindowController()
        registerHotkey()
        configureVoice()
        // TEMP DEBUG: don't auto-start wake-word at app launch so we
        // can isolate whether SFSpeechRecognizer-driven audio engine is
        // breaking keyboard routing.
        // if settings.wakeWordEnabled {
        //     wakeWord.start()
        // }
    }

    private func ensureOrchestrator() -> ConversationOrchestrator {
        if let orchestrator { return orchestrator }
        let o = ConversationOrchestrator(appState: self)
        orchestrator = o
        return o
    }

    private func registerHotkey() {
        // TEMP DEBUG: DoubleTapModifier disabled to test if its global
        // flagsChanged monitor is what's breaking key routing.
        // doubleTap.modifier = .option
        // doubleTap.onTrigger = { [weak self] in
        //     Task { @MainActor in self?.togglePanel() }
        // }
        // doubleTap.start()
        hotkey.onTrigger = { [weak self] in
            Task { @MainActor in self?.togglePanel() }
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
            self?.micAmplitude = 0
        }
        dictation.onLevel = { [weak self] level in
            self?.micAmplitude = level
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
        latestResponseCard = nil
        voiceMode = true
        wakeWord.pause()
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

    /// Called from the orchestrator when the LLM invokes end_session
    /// with action="stop_voice". Turns off voice mode but leaves the
    /// panel up so the user can read the final response.
    func stopVoiceOnly() {
        voiceMode = false
        if isListening { stopDictation(cancel: true) }
    }

    private func startDictation() {
        // Pause wake word so we don't pick up our own input.
        wakeWord.pause()
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
        micAmplitude = 0
        // While the panel is open we leave wake-word OFF so keyboard
        // routing stays clean. Wake-word resumes only when the panel
        // closes (see finishClose).
    }

    private func resumeWakeWordIfEnabled() {
        guard settings.wakeWordEnabled else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            wakeWord.resume()
        }
    }

    func togglePanel() {
        if orbController.isShown && !orbController.isClosing {
            requestClose()
        } else {
            if orbController.isShown {
                orbController.hide()
            }
            phase = .idle
            inputText = ""
            latestResponse = ""
            latestResponseCard = nil
            // The wake-word audio engine running in the background can
            // interfere with the panel's keyboard routing on macOS 26.
            // Pause it while the panel is open; resume on close. The
            // panel itself has its own dictation engine for voice input.
            wakeWord.pause()
            orbController.show(appState: self)
            if settings.voiceOnShortcut {
                voiceMode = true
                startDictation()
            }
        }
    }

    /// True while a turn is in flight (thinking, streaming, or running
    /// a tool). The input row uses this to block new submissions until
    /// the current response finishes.
    var isGenerating: Bool {
        switch phase {
        case .thinking, .toolCalling: return true
        default: return false
        }
    }

    func submit() {
        // Block re-entry while a turn is already in flight so the user
        // can't pile prompts on top of a generating response.
        if isGenerating { return }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isListening { stopDictation(cancel: false) }
        if !latestResponse.isEmpty {
            pastResponses.append(latestResponse)
        }
        inputText = ""
        latestResponse = ""
        latestResponseCard = nil
        submitPulseCounter += 1
        // Capture voice intent now; the orchestrator may flip it off
        // mid-turn if the LLM calls end_session.
        let submittedFromVoice = voiceMode
        Task { [weak self] in
            guard let self else { return }
            await self.ensureOrchestrator().turn(userText: trimmed)
            // Re-arm voice ONLY if we started in voice mode AND the LLM
            // didn't end the session AND the panel is still open.
            guard submittedFromVoice,
                  self.voiceMode,
                  self.orbController.isShown,
                  !self.orbController.isClosing else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            // Re-check after the sleep — could have closed or stopped
            // voice in the meantime (e.g. user clicked the mic button).
            guard self.voiceMode,
                  self.orbController.isShown,
                  !self.orbController.isClosing else { return }
            self.startDictation()
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
        latestResponseCard = nil
        pastResponses.removeAll()
        if isListening { dictation.cancel() }
        isListening = false
        micAmplitude = 0
        voiceMode = false
        // Fully tear down wake-word so a stale audio engine doesn't
        // linger across close → open cycles, then schedule a fresh
        // start with a small delay so macOS has time to release the
        // mic device.
        wakeWord.stop()
        resumeWakeWordIfEnabled()
        orchestrator?.resetSession()
    }

    /// Called from Settings when the user flips the wake-word checkbox.
    func applyWakeWordSetting() {
        if settings.wakeWordEnabled {
            wakeWord.start()
        } else {
            // Hard-stop the engine and DO NOT auto-resume it after the
            // next dictation cycle. The mic is only opened when the user
            // explicitly taps the mic button.
            wakeWord.stop()
        }
    }
}

enum ToolLabel {
    /// Maps a raw tool function name (the string the model uses) into a
    /// short, human-readable verb phrase suitable for the status line.
    /// Anything unknown is title-cased and stripped of underscores so it
    /// at least doesn't look like an identifier.
    static func friendly(_ rawName: String) -> String {
        switch rawName {
        case "create_reminder":        return "Creating a reminder"
        case "list_reminders":         return "Looking up reminders"
        case "create_calendar_event":  return "Adding to your calendar"
        case "list_calendar_events":   return "Checking your calendar"
        case "set_timer":              return "Setting a timer"
        case "weather":                return "Checking the weather"
        case "calculate":              return "Crunching the numbers"
        case "world_clock":            return "Checking the time"
        case "take_note":              return "Saving a note"
        case "search_files":           return "Searching your files"
        case "web_search":             return "Searching the web"
        case "wikipedia":              return "Reading Wikipedia"
        case "music_control":          return "Controlling music"
        case "lookup_contact":         return "Finding the contact"
        case "send_imessage":          return "Sending a message"
        case "send_email":             return "Drafting your email"
        case "open_app":               return "Opening the app"
        case "quit_app":               return "Quitting the app"
        case "open_url":               return "Opening the link"
        case "system_control":         return "Adjusting settings"
        case "end_session":            return "Wrapping up"
        default:
            return rawName
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}
