import Foundation
import EventKit

struct CreateCalendarEventTool: Tool {
    let name = "create_calendar_event"
    let displayName = "Create calendar event"
    let description = "Create a calendar event. Start time is required in ISO8601. Default duration 60 min."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "title": ["type": "string"],
            "start_iso8601": ["type": "string", "description": "ISO8601 start time."],
            "end_iso8601":   ["type": "string", "description": "Optional ISO8601 end time."],
            "location":      ["type": "string"],
            "notes":         ["type": "string"]
        ]),
        "required": AnyCodable(["title", "start_iso8601"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let title = args["title"] as? String,
              let startStr = args["start_iso8601"] as? String,
              let start = ISO8601DateFormatter().date(from: startStr) else {
            throw ToolError.invalidArguments
        }
        let end: Date = {
            if let endStr = args["end_iso8601"] as? String,
               let e = ISO8601DateFormatter().date(from: endStr) { return e }
            return start.addingTimeInterval(3600)
        }()

        let store = EKEventStore()
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw ToolError.denied("Calendar access denied.") }

        let ev = EKEvent(eventStore: store)
        ev.title = title
        ev.startDate = start
        ev.endDate = end
        ev.location = args["location"] as? String
        ev.notes = args["notes"] as? String
        ev.calendar = store.defaultCalendarForNewEvents

        try store.save(ev, span: .thisEvent, commit: true)

        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        return "Event created: \(title) — \(f.string(from: start))."
    }
}

struct ListCalendarEventsTool: Tool {
    let name = "list_calendar_events"
    let displayName = "List calendar events"
    let description = "List upcoming calendar events. Default: today + tomorrow."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "days_ahead": ["type": "number", "description": "How many days ahead to include. Default 2 (today+tomorrow)."]
        ]),
        "required": AnyCodable([] as [String])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        let days = Int((args["days_ahead"] as? Double) ?? 2)

        let store = EKEventStore()
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw ToolError.denied("Calendar access denied.") }

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        if events.isEmpty { return "No events in the next \(days) day(s)." }
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        let lines = events.prefix(20).map { ev -> String in
            "• \(ev.title ?? "(untitled)") — \(f.string(from: ev.startDate))" +
            (ev.location.map { " @ \($0)" } ?? "")
        }
        return lines.joined(separator: "\n")
    }
}
