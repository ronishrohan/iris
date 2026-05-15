import AppKit
import SwiftUI

@MainActor
final class OrbWindowController {
    private var panel: NSPanel?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(appState: AppState) {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let content = OrbView()
            .environment(appState)

        let hosting = NSHostingController(rootView: content)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.backgroundColor = .clear
        p.hasShadow = true
        p.contentViewController = hosting
        p.center()

        panel = p
        p.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }
}
