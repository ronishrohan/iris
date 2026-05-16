import Foundation
import UserNotifications

struct SetTimerTool: Tool {
    let name = "set_timer"
    let displayName = "Set timer"
    let description = "Set a timer that will fire a local notification after a given number of seconds. Combine seconds, minutes, hours as needed."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "seconds": ["type": "number", "description": "Seconds to wait. 0 if unused."],
            "minutes": ["type": "number", "description": "Minutes to wait. 0 if unused."],
            "hours":   ["type": "number", "description": "Hours to wait. 0 if unused."],
            "label":   ["type": "string", "description": "Optional label shown in the notification."]
        ]),
        "required": AnyCodable([] as [String])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        let h = (args["hours"]   as? Double) ?? 0
        let m = (args["minutes"] as? Double) ?? 0
        let s = (args["seconds"] as? Double) ?? 0
        let label = (args["label"] as? String) ?? "Timer done"

        let total = h * 3600 + m * 60 + s
        guard total > 0 else { throw ToolError.invalidArguments }

        try await requestAuth()

        let content = UNMutableNotificationContent()
        content.title = "Iris"
        content.body = label
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: total, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(req)

        return "Timer set for \(formatDuration(total)) (\(label))."
    }

    private func requestAuth() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        if !granted { throw ToolError.denied("Notification permission denied — timer would fire silently.") }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if sec > 0 { parts.append("\(sec)s") }
        return parts.joined(separator: " ")
    }
}
