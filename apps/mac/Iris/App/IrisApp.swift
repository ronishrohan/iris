import SwiftUI

@main
struct IrisApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Iris", systemImage: "waveform") {
            MenuBarContent()
                .environment(appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(appState)
                .frame(minWidth: 640, minHeight: 460)
        }
    }
}
