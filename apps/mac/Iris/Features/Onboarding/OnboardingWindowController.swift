import AppKit
import SwiftUI

private final class OnboardingPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static var shared: OnboardingWindowController?

    private var window: NSWindow?

    static func showIfNeeded(appState: AppState) {
        guard !appState.settings.hasCompletedOnboarding else { return }
        let controller = OnboardingWindowController()
        shared = controller
        controller.show(appState: appState)
    }

    func show(appState: AppState) {
        let content = OnboardingRootView(appState: appState, onComplete: { [weak self] in
            self?.close()
        })
        let hosting = NSHostingController(rootView: content)

        let win = OnboardingPanel(contentViewController: hosting)
        win.styleMask = [.borderless, .fullSizeContentView]
        win.isMovable = false
        win.isMovableByWindowBackground = false
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.setContentSize(NSSize(width: 454, height: 459))
        win.minSize = NSSize(width: 454, height: 459)
        win.maxSize = NSSize(width: 600, height: 620)
        win.animationBehavior = .documentWindow
        win.level = .floating
        win.center()
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func bringToFront() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func close() {
        window?.close()
        window = nil
        OnboardingWindowController.shared = nil
    }

    // Prevent closing the window by clicking the red X during onboarding
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return false
    }
}
