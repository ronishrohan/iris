import SwiftUI
import Observation

@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case idle
        case wakeDetected
        case listening
        case transcribing
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

    init() {
        self.orbController = OrbWindowController()
        registerHotkey()
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
            orbController.hide()
            phase = .idle
        } else {
            orbController.show(appState: self)
            phase = .listening
        }
    }
}
