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
        try await runRich(argumentsJSON: argumentsJSON).modelText
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
        let args = try parseArguments(argumentsJSON)
        guard let title = args["title"] as? String, !title.isEmpty else { throw ToolError.invalidArguments }
        let due = args["due_iso8601"] as? String
        let listName = args["list"] as? String

        let store = EKEventStore()
        let granted = try await store.requestFullAccessToReminders()
        guard granted else { throw ToolError.denied("Reminders access denied.") }

        let r = EKReminder(eventStore: store)
        r.title = title
        var dueDate: Date? = nil
        if let due, let date = ISO8601DateFormatter().date(from: due) {
            r.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date)
            r.addAlarm(EKAlarm(absoluteDate: date))
            dueDate = date
        }
        let chosenList: EKCalendar
        if let listName, let list = store.calendars(for: .reminder)
            .first(where: { $0.title.lowercased() == listName.lowercased() }) {
            chosenList = list
        } else {
            chosenList = store.defaultCalendarForNewReminders() ?? store.calendars(for: .reminder).first!
        }
        r.calendar = chosenList
        try store.save(r, commit: true)

        let summary = "Reminder created: \(title)\(due.map { " at \($0)" } ?? "")."
        let card = ReminderCardData(
            title: title,
            due: dueDate,
            listName: chosenList.title,
            listColorHex: Self.hex(from: chosenList.cgColor),
            calendarItemIdentifier: r.calendarItemIdentifier
        )
        return .rich(text: summary, ui: ToolUIResult(kind: .reminder(card)))
    }

    static func hex(from cg: CGColor?) -> String? {
        guard let cg, let comps = cg.components, comps.count >= 3 else { return nil }
        let r = Int((max(0, min(1, comps[0])) * 255).rounded())
        let g = Int((max(0, min(1, comps[1])) * 255).rounded())
        let b = Int((max(0, min(1, comps[2])) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
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
        try await runRich(argumentsJSON: argumentsJSON).modelText
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
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
        if reminders.isEmpty {
            return .text("No upcoming reminders in the next \(days) day(s).")
        }

        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short

        let cards = reminders.prefix(20).map { r -> ReminderCardData in
            let date: Date?
            if let comps = r.dueDateComponents {
                date = Calendar.current.date(from: comps)
            } else {
                date = nil
            }
            return ReminderCardData(
                title: r.title ?? "(untitled)",
                due: date,
                listName: r.calendar?.title,
                listColorHex: CreateReminderTool.hex(from: r.calendar?.cgColor),
                calendarItemIdentifier: r.calendarItemIdentifier
            )
        }
        let summaryLines = cards.map { r -> String in
            var s = "• \(r.title)"
            if let d = r.due { s += " — \(f.string(from: d))" }
            return s
        }
        return .rich(text: summaryLines.joined(separator: "\n"),
                     ui: ToolUIResult(kind: .reminderList(Array(cards))))
    }
}
