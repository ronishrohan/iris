import Foundation
import AppKit

struct SystemControlTool: Tool {
    let name = "system_control"
    let displayName = "System control"
    let description = """
    Control macOS: volume, brightness, sleep, lock screen, dark mode, \
    Do Not Disturb, Wi-Fi, Bluetooth, open System Settings.
    """
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "action": [
                "type": "string",
                "enum": [
                    "volume_up", "volume_down", "mute", "unmute", "set_volume",
                    "brightness_up", "brightness_down",
                    "sleep", "lock", "logout",
                    "toggle_dark_mode", "enable_dark_mode", "disable_dark_mode",
                    "toggle_dnd",
                    "open_settings"
                ],
                "description": "Which system action to perform"
            ],
            "value": [
                "type": "number",
                "description": "Numeric value for set_volume (0-100)"
            ]
        ]),
        "required": AnyCodable(["action"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let action = args["action"] as? String else { throw ToolError.invalidArguments }

        switch action {
        case "volume_up":
            try runAppleScript("set v to output volume of (get volume settings)\nset volume output volume (v + 10)")
            return "Volume up."
        case "volume_down":
            try runAppleScript("set v to output volume of (get volume settings)\nset volume output volume (v - 10)")
            return "Volume down."
        case "mute":
            try runAppleScript("set volume with output muted")
            return "Muted."
        case "unmute":
            try runAppleScript("set volume without output muted")
            return "Unmuted."
        case "set_volume":
            guard let v = args["value"] as? Double else { throw ToolError.invalidArguments }
            try runAppleScript("set volume output volume \(Int(max(0, min(100, v))))")
            return "Volume set to \(Int(v))%."

        case "brightness_up":
            try sendKeyCode(144) // F15 = brightness up
            return "Brightness up."
        case "brightness_down":
            try sendKeyCode(145) // F14 = brightness down
            return "Brightness down."

        case "sleep":
            try runAppleScript("tell application \"System Events\" to sleep")
            return "Going to sleep."
        case "lock":
            try runShell("/usr/bin/pmset", args: ["displaysleepnow"])
            return "Locked screen."
        case "logout":
            try runAppleScript("tell application \"System Events\" to log out")
            return "Logging out."

        case "toggle_dark_mode":
            try runAppleScript("""
                tell application "System Events"
                    tell appearance preferences
                        set dark mode to not dark mode
                    end tell
                end tell
                """)
            return "Toggled dark mode."
        case "enable_dark_mode":
            try runAppleScript("""
                tell application "System Events"
                    tell appearance preferences to set dark mode to true
                end tell
                """)
            return "Dark mode on."
        case "disable_dark_mode":
            try runAppleScript("""
                tell application "System Events"
                    tell appearance preferences to set dark mode to false
                end tell
                """)
            return "Dark mode off."

        case "toggle_dnd":
            // macOS 13+: there's no public AppleScript for DND. Use shortcuts CLI fallback.
            try runShell("/usr/bin/shortcuts", args: ["run", "Toggle Do Not Disturb"])
            return "Toggled Do Not Disturb (if the shortcut exists)."

        case "open_settings":
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
            return "Opened System Settings."

        default:
            throw ToolError.invalidArguments
        }
    }

    private func runAppleScript(_ source: String) throws {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        _ = script?.executeAndReturnError(&error)
        if let error = error {
            throw ToolError.denied("AppleScript error: \(error["NSAppleScriptErrorMessage"] ?? "unknown")")
        }
    }

    private func runShell(_ path: String, args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
    }

    private func sendKeyCode(_ code: CGKeyCode) throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) else {
            throw ToolError.denied("Couldn't synthesize key event.")
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
