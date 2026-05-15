import Foundation
import EventKit

struct RemindersTool: Tool {
    let name = "create_reminder"
    let displayName = "Create reminder"
    let description = "Create a reminder in the default Reminders list."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "title": ["type": "string"],
            "due_date_iso8601": ["type": "string", "description": "Optional ISO-8601 due date."]
        ]),
        "required": AnyCodable(["title"])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        guard let title = arguments["title"] as? String else { throw ToolError.invalidArguments }
        let store = EKEventStore()
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await store.requestFullAccessToReminders()
        } else {
            granted = try await withCheckedThrowingContinuation { cont in
                store.requestAccess(to: .reminder) { ok, err in
                    if let err { cont.resume(throwing: err) } else { cont.resume(returning: ok) }
                }
            }
        }
        guard granted else { throw ToolError.denied("Reminders access denied.") }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let iso = arguments["due_date_iso8601"] as? String,
           let d = ISO8601DateFormatter().date(from: iso) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year,.month,.day,.hour,.minute], from: d)
        }
        try store.save(reminder, commit: true)
        return "Created reminder \"\(title)\"."
    }
}
