import Foundation
import EventKit

struct CreateReminderTool: Tool {
    let name = "create_reminder"
    let displayName = "Create reminder"
    let description = "Create a reminder in macOS Reminders. Optional due date in ISO8601 (e.g. 2026-06-01T18:00:00)."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "title": ["type": "string", "description": "Title of the reminder."],
            "due_iso8601": ["type": "string", "description": "Optional ISO8601 due date/time."],
            "list": ["type": "string", "description": "Optional reminder list name."]
        ]),
        "required": AnyCodable(["title"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let title = args["title"] as? String, !title.isEmpty else { throw ToolError.invalidArguments }
        let due = args["due_iso8601"] as? String
        let listName = args["list"] as? String

        let store = EKEventStore()
        let granted = try await store.requestFullAccessToReminders()
        guard granted else { throw ToolError.denied("Reminders access denied.") }

        let r = EKReminder(eventStore: store)
        r.title = title
        if let due, let date = ISO8601DateFormatter().date(from: due) {
            r.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date)
            r.addAlarm(EKAlarm(absoluteDate: date))
        }
        if let listName, let list = store.calendars(for: .reminder).first(where: { $0.title.lowercased() == listName.lowercased() }) {
            r.calendar = list
        } else {
            r.calendar = store.defaultCalendarForNewReminders()
        }
        try store.save(r, commit: true)
        return "Reminder created: \(title)\(due.map { " at \($0)" } ?? "")."
    }
}

struct ListRemindersTool: Tool {
    let name = "list_reminders"
    let displayName = "List reminders"
    let description = "List upcoming incomplete reminders (default: due in next 7 days)."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "days_ahead": ["type": "number", "description": "How many days ahead to include. Default 7."]
        ]),
        "required": AnyCodable([] as [String])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        let days = Int((args["days_ahead"] as? Double) ?? 7)

        let store = EKEventStore()
        let granted = try await store.requestFullAccessToReminders()
        guard granted else { throw ToolError.denied("Reminders access denied.") }

        let end = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: end, calendars: nil
        )

        let reminders: [EKReminder] = try await withCheckedThrowingContinuation { cont in
            store.fetchReminders(matching: predicate) { res in
                cont.resume(returning: res ?? [])
            }
        }
        if reminders.isEmpty { return "No upcoming reminders in the next \(days) day(s)." }
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short

        let lines = reminders.prefix(20).map { r -> String in
            var s = "• \(r.title ?? "(untitled)")"
            if let comps = r.dueDateComponents, let d = Calendar.current.date(from: comps) {
                s += " — \(f.string(from: d))"
            }
            return s
        }
        return lines.joined(separator: "\n")
    }
}
