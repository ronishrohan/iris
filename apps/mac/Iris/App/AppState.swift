import SwiftUI
import Observation

@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case idle
        case listening
        case thinking
        case toolCalling(name: String)
        case speaking
        case error(String)
    }

    var phase: Phase = .idle
    var latestTranscript: String = ""
    var latestResponse: String = ""

    let settings = AppSettings()
    let orbController: OrbWindowController
    let hotkey = GlobalHotkey()
    private var stt: AppleSTT?
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
                self?.toggleOrb()
            }
        }
        hotkey.register(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)
    }

    func toggleOrb() {
        if orbController.isVisible {
            stopListening()
            orbController.hide()
            phase = .idle
        } else {
            orbController.show(appState: self)
            startListening()
        }
    }

    private func startListening() {
        latestTranscript = ""
        latestResponse = ""
        phase = .listening
        let service = AppleSTT()
        self.stt = service
        Task { [weak self] in
            guard let self else { return }
            do {
                try await service.start(
                    onPartial: { partial in
                        Task { @MainActor in self.latestTranscript = partial }
                    },
                    onFinal: { final in
                        Task { @MainActor in
                            self.latestTranscript = final
                            self.stt?.stop()
                            self.stt = nil
                            await self.ensureOrchestrator().turn(userText: final)
                        }
                    },
                    onError: { err in
                        Task { @MainActor in self.phase = .error(err.localizedDescription) }
                    }
                )
            } catch {
                await MainActor.run { self.phase = .error(error.localizedDescription) }
            }
        }
    }

    private func stopListening() {
        stt?.stop()
        stt = nil
    }
}
