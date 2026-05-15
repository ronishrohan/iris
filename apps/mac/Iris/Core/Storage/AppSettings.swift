import Foundation
import Observation
import Carbon.HIToolbox

@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: K.launchAtLogin) }
        set { defaults.set(newValue, forKey: K.launchAtLogin) }
    }

    var deepseekApiKey: String {
        get { KeychainStore.shared.get(K.deepseekApiKey) ?? "" }
        set { KeychainStore.shared.set(newValue, for: K.deepseekApiKey) }
    }

    var defaultModel: String {
        get { defaults.string(forKey: K.defaultModel) ?? "deepseek-v4-flash" }
        set { defaults.set(newValue, forKey: K.defaultModel) }
    }

    var useThinkingMode: Bool {
        get { defaults.bool(forKey: K.useThinkingMode) }
        set { defaults.set(newValue, forKey: K.useThinkingMode) }
    }

    var wakeWordEnabled: Bool {
        get { (defaults.object(forKey: K.wakeWordEnabled) as? Bool) ?? false }
        set { defaults.set(newValue, forKey: K.wakeWordEnabled) }
    }

    var wakeWordSensitivity: Double {
        get { (defaults.object(forKey: K.wakeWordSensitivity) as? Double) ?? 0.6 }
        set { defaults.set(newValue, forKey: K.wakeWordSensitivity) }
    }

    var sttEngine: String {
        get { defaults.string(forKey: K.sttEngine) ?? "apple" }
        set { defaults.set(newValue, forKey: K.sttEngine) }
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

    func isToolEnabled(_ name: String) -> Bool {
        let key = "tool.\(name).enabled"
        return (defaults.object(forKey: key) as? Bool) ?? true
    }

    func setTool(_ name: String, enabled: Bool) {
        defaults.set(enabled, forKey: "tool.\(name).enabled")
    }

    private enum K {
        static let launchAtLogin = "launchAtLogin"
        static let deepseekApiKey = "deepseekApiKey"
        static let defaultModel = "defaultModel"
        static let useThinkingMode = "useThinkingMode"
        static let wakeWordEnabled = "wakeWordEnabled"
        static let wakeWordSensitivity = "wakeWordSensitivity"
        static let sttEngine = "sttEngine"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
    }
}
