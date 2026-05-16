import AppKit
import SwiftUI

@MainActor
final class OrbWindowController {
    private var panel: KeyablePanel?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(appState: AppState) {
        // Always rebuild from scratch so SwiftUI's onAppear fires and the
        // Spotlight-style enter animation runs every time.
        hide()

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        // Full-screen overlay window. The panel itself is the entire screen
        // and the SwiftUI content is centered inside it. This means the
        // enter/exit scale animations never get clipped by the window edge.
        let content = IrisPanelHostView()
            .environment(appState)
            .frame(width: frame.width, height: frame.height)

        let hosting = NSHostingController(rootView: content)

        let p = KeyablePanel(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.isMovable = false
        p.isMovableByWindowBackground = false
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.ignoresMouseEvents = false
        p.contentViewController = hosting
        p.setFrame(frame, display: true)

        panel = p

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.contentViewController = nil
        panel = nil
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

/// Wraps the actual panel content and lays it out centered horizontally,
/// vertically biased upward by ~10% of the screen height (same anchor as
/// Spotlight). Click-through outside the content area so the rest of the
/// screen still works.
struct IrisPanelHostView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // A near-invisible catch layer so clicks anywhere outside
                // the panel content close it. Almost transparent — does not
                // dim the screen.
                Color.black.opacity(0.0001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.dismiss()
                    }

                IrisPanelView()
                    .offset(y: -geo.size.height * 0.10)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}
