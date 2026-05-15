import Foundation

@MainActor
final class ToolRegistry {
    static let builtIns: [any Tool] = [
        OpenAppTool(),
        WebSearchTool(),
        RemindersTool(),
        MessagesTool(),
        SpotifyTool(),
        MusicAppTool(),
        SystemControlTool(),
        ScreenshotTool(),
        ShellTool()
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
