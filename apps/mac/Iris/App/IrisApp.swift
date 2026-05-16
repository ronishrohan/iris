import SwiftUI
import AppKit

@main
struct IrisApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: IrisAppDelegate

    var body: some Scene {
        MenuBarExtra("Iris", systemImage: "waveform") {
            MenuBarContent()
                .environment(appDelegate.appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(appDelegate.appState)
                .frame(minWidth: 640, minHeight: 460)
        }
    }
}

@MainActor
final class IrisAppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        OnboardingWindowController.showIfNeeded(appState: appState)
    }
}
