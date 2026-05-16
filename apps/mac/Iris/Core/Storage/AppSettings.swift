import Foundation
import Observation
import Carbon.HIToolbox

@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    // Stored in UserDefaults rather than the keychain so unsigned/ad-hoc
    // dev builds don't trigger a "Iris wants to use your confidential
    // information" prompt every time the signature changes. Swap back to
    // KeychainStore once the app ships with a stable signing identity.
    var deepseekApiKey: String {
        get { defaults.string(forKey: K.deepseekApiKey) ?? "" }
        set { defaults.set(newValue, forKey: K.deepseekApiKey) }
    }

    var defaultModel: String {
        get { defaults.string(forKey: K.defaultModel) ?? "deepseek-v4-flash" }
        set { defaults.set(newValue, forKey: K.defaultModel) }
    }

    // Hotkey: default ⌥-Space
    var hotkeyKeyCode: UInt32 {
        get { UInt32((defaults.object(forKey: K.hotkeyKeyCode) as? Int) ?? Int(kVK_Space)) }
        set { defaults.set(Int(newValue), forKey: K.hotkeyKeyCode) }
    }

    var hotkeyModifiers: UInt32 {
        get { UInt32((defaults.object(forKey: K.hotkeyModifiers) as? Int) ?? Int(optionKey)) }
        set { defaults.set(Int(newValue), forKey: K.hotkeyModifiers) }
    }

    /// Whether the "Hey Iris" wake-word engine should run while the
    /// app is open. Defaults to on.
    var wakeWordEnabled: Bool {
        get { (defaults.object(forKey: K.wakeWordEnabled) as? Bool) ?? true }
        set { defaults.set(newValue, forKey: K.wakeWordEnabled) }
    }

    func isToolEnabled(_ name: String) -> Bool {
        let key = "tool.\(name).enabled"
        return (defaults.object(forKey: key) as? Bool) ?? true
    }

    func setTool(_ name: String, enabled: Bool) {
        defaults.set(enabled, forKey: "tool.\(name).enabled")
    }

    private enum K {
        static let deepseekApiKey = "deepseekApiKey"
        static let defaultModel = "defaultModel"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let wakeWordEnabled = "wakeWordEnabled"
    }
}
