import SwiftUI

/// Resolves a `ToolUIResult` into the right card view. The orb's
/// response area uses this whenever `AppState.latestResponseCard` is
/// non-nil; otherwise it falls back to the plain prose response.
struct ResponseCardHost: View {
    let ui: ToolUIResult

    var body: some View {
        switch ui.kind {
        case .reminder(let data):
            ReminderCard(data: data)
        case .reminderList(let items):
            ReminderListCard(items: items)
        case .calendarEvent(let data):
            CalendarEventCard(data: data)
        case .calendarEventList(let items):
            CalendarEventListCard(items: items)
        case .timer(let data):
            TimerCard(data: data)
        case .weather(let data):
            WeatherCard(data: data)
        case .calculation(let data):
            CalculationCard(data: data)
        case .worldClock(let data):
            WorldClockCard(data: data)
        case .note(let data):
            NoteCard(data: data)
        case .fileList(let items):
            FileListCard(items: items)
        case .webResults(let items):
            WebResultsCard(items: items)
        case .wikipedia(let data):
            WikipediaCard(data: data)
        case .music(let data):
            MusicCard(data: data)
        case .contact(let data):
            ContactCard(data: data)
        case .messageSent(let data):
            MessageSentCard(data: data)
        case .emailSent(let data):
            EmailSentCard(data: data)
        }
    }
}
