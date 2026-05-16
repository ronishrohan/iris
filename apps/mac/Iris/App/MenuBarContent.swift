import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Activate Iris") {
            appState.togglePanel()
        }
        .keyboardShortcut(.space, modifiers: [.option])

        Divider()

        Text(phaseLabel)
            .font(.caption)
            .foregroundStyle(.secondary)

        Divider()

        Button("Settings…") { openSettings() }
            .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit Iris") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: [.command])
    }

    private var phaseLabel: String {
        switch appState.phase {
        case .idle: "Idle"
        case .thinking: "Thinking…"
        case .toolCalling(let name): "\(ToolLabel.friendly(name))…"
        case .done: "Done"
        case .error(let msg): "Error: \(msg)"
        }
    }
}
