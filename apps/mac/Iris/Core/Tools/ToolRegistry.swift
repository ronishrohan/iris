import Foundation

@MainActor
final class ToolRegistry {
    static let builtIns: [any Tool] = [
        // App control
        OpenAppTool(),
        QuitAppTool(),
        OpenURLTool(),

        // System
        SystemControlTool(),

        // Quick utilities
        WorldClockTool(),
        CalculateTool(),
        SetTimerTool(),

        // Knowledge
        WebSearchTool(),
        WikipediaTool(),
        WeatherTool(),

        // Productivity
        CreateReminderTool(),
        ListRemindersTool(),
        CreateCalendarEventTool(),
        ListCalendarEventsTool(),
        TakeNoteTool(),
        SearchFilesTool(),

        // Communication
        SendIMessageTool(),
        SendEmailTool(),
        LookupContactTool(),

        // Media
        MusicControlTool(),

        // Session control
        EndSessionTool()
    ]

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func enabledTools() -> [any Tool] {
        Self.builtIns.filter { settings.isToolEnabled($0.name) }
    }

    func find(_ name: String) -> (any Tool)? {
        Self.builtIns.first { $0.name == name }
    }
}
