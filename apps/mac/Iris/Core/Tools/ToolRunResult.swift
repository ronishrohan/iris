import Foundation
import AppKit

/// Outcome of a tool invocation. Tools either return plain text (which
/// is what the model sees as the tool result) or rich content — a
/// strongly-typed payload that the UI renders as a native-style card,
/// alongside the same text summary fed back to the model.
enum ToolRunResult: Sendable {
    case text(String)
    case rich(text: String, ui: ToolUIResult)

    var modelText: String {
        switch self {
        case .text(let s): return s
        case .rich(let s, _): return s
        }
    }

    var ui: ToolUIResult? {
        if case .rich(_, let ui) = self { return ui }
        return nil
    }
}

/// Structured UI payload that the orchestrator forwards to AppState so
/// the response view can swap in a per-task card instead of (or in
/// addition to) the prose response.
struct ToolUIResult: Sendable {
    enum Kind: Sendable {
        case reminder(ReminderCardData)
        case reminderList([ReminderCardData])
        case calendarEvent(CalendarEventCardData)
        case calendarEventList([CalendarEventCardData])
        case timer(TimerCardData)
        case weather(WeatherCardData)
        case calculation(CalculationCardData)
        case worldClock(WorldClockCardData)
        case note(NoteCardData)
        case fileList([FileCardData])
        case webResults([WebResultCardData])
        case wikipedia(WikipediaCardData)
        case music(MusicCardData)
        case contact(ContactCardData)
        case messageSent(MessageSentCardData)
        case emailSent(EmailSentCardData)
    }

    let kind: Kind
}

// MARK: - Per-card payloads

struct ReminderCardData: Sendable, Hashable {
    let title: String
    let due: Date?
    let listName: String?
    /// Hex string like "#FF8800" if known; nil → fall back to a default.
    let listColorHex: String?
    /// EKReminder external identifier when available — used to build the
    /// deep link straight back to this item.
    let calendarItemIdentifier: String?
}

struct CalendarEventCardData: Sendable, Hashable {
    let title: String
    let start: Date
    let end: Date?
    let location: String?
    let calendarName: String?
    let calendarColorHex: String?
    let eventIdentifier: String?
}

struct TimerCardData: Sendable, Hashable {
    let label: String
    let totalSeconds: Double
    /// The wall-clock moment the timer will fire — the UI subtracts
    /// now() from this to render a live countdown.
    let fireDate: Date
}

struct WeatherCardData: Sendable, Hashable {
    let city: String
    let conditionSymbol: String   // SF Symbol name, e.g. "cloud.sun.fill"
    let temperatureText: String   // "72°"
    let highLowText: String?      // "H:78° L:60°"
    let summary: String?          // "Partly cloudy"
}

struct CalculationCardData: Sendable, Hashable {
    let expression: String
    let result: String
}

struct WorldClockCardData: Sendable, Hashable {
    let city: String
    let timeText: String          // "3:42 PM"
    let dateText: String?         // "Tomorrow" / "Today" / "Fri 17"
    /// True if it's daytime in that city — flips the gradient.
    let isDaytime: Bool
}

struct NoteCardData: Sendable, Hashable {
    let preview: String           // First few lines of the note body
    let folder: String?
}

struct FileCardData: Sendable, Hashable {
    let name: String
    let path: String
    /// Hint for the SF Symbol fallback; resolved at render time from
    /// the file URL when available.
    let kindHint: String
}

struct WebResultCardData: Sendable, Hashable {
    let title: String
    let url: String
    let snippet: String?
}

struct WikipediaCardData: Sendable, Hashable {
    let title: String
    let summary: String
    let url: String?
}

struct MusicCardData: Sendable, Hashable {
    let title: String?
    let artist: String?
    let action: String            // "Playing" / "Paused" / "Skipped" / etc.
}

struct ContactCardData: Sendable, Hashable {
    let name: String
    let primaryPhone: String?
    let primaryEmail: String?
    let initials: String
}

struct MessageSentCardData: Sendable, Hashable {
    let recipient: String
    let preview: String
}

struct EmailSentCardData: Sendable, Hashable {
    let recipient: String
    let subject: String
    let preview: String?
}
