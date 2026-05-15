import Foundation
import Observation
import Carbon.HIToolbox

@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var deepseekApiKey: String {
        get { KeychainStore.shared.get(K.deepseekApiKey) ?? "" }
        set { KeychainStore.shared.set(newValue, for: K.deepseekApiKey) }
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
    }
}
