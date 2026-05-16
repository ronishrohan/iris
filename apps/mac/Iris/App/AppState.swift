import SwiftUI
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

    /// Bumped each time the panel should animate itself closed. The view
    /// observes this, plays the exit animation, then calls
    /// `finishClose()` so the controller can tear down the window.
    var closeRequestCounter: Int = 0

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
        if orbController.isVisible {
            requestClose()
        } else {
            phase = .idle
            inputText = ""
            latestResponse = ""
            orbController.show(appState: self)
        }
    }

    func submit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        latestResponse = ""
        Task { [weak self] in
            guard let self else { return }
            await self.ensureOrchestrator().turn(userText: trimmed)
        }
    }

    func requestClose() {
        guard orbController.isVisible else { return }
        closeRequestCounter += 1
    }

    func dismiss() { requestClose() }

    func finishClose() {
        orbController.hide()
        phase = .idle
        inputText = ""
        latestResponse = ""
    }
}
