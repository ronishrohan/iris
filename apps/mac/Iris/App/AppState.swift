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

    let settings = AppSettings()
    let orbController: OrbWindowController
    let hotkey = GlobalHotkey()
    private var orchestrator: ConversationOrchestrator?

    init() {
        self.orbController = OrbWindowController()
        registerHotkey()
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
        // Push the currently-visible response onto the stack BEFORE we
        // wipe latestResponse, so the previous answer stays on screen as
        // a card behind the incoming new one.
        if !latestResponse.isEmpty {
            pastResponses.append(latestResponse)
        }
        inputText = ""
        latestResponse = ""
        submitPulseCounter += 1
        Task { [weak self] in
            guard let self else { return }
            await self.ensureOrchestrator().turn(userText: trimmed)
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
        orchestrator?.resetSession()
    }
}
