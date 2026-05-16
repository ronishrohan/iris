import AppKit
import SwiftUI

@MainActor
final class OrbWindowController {
    private var panel: PassThroughPanel?

    /// True from the moment `show` runs until `hide` tears the panel down.
    /// Stays true *during* the close animation, so the state machine in
    /// AppState can distinguish "open and closing" from "fully closed".
    private(set) var isShown: Bool = false

    /// True between requesting the exit animation and the panel actually
    /// being torn down. Used to coalesce close requests.
    var isClosing: Bool = false

    /// Bundle id of the app that was frontmost right before we showed the
    /// panel, so we can hand focus back when we hide.
    private var previousFrontmostBundleID: String?

    /// Global mouse-down monitor that fires for clicks in *other* apps.
    /// Used to dismiss when the user clicks outside our window bounds
    /// (e.g. in another window we don't cover, like a side display).
    private var globalMouseMonitor: Any?

    /// Local mouse-down monitor that fires for clicks inside our own
    /// window. We use it to detect taps on the empty pass-through area
    /// and dismiss, while letting the click also fall through to the app
    /// underneath via the PassThroughPanel hit-test.
    private var localMouseMonitor: Any?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(appState: AppState) {
        // Track previous frontmost app only as a safety net — with the
        // non-activating panel we shouldn't actually steal focus, but if
        // for any reason we do, hide() will hand it back.
        let ourBundleID = Bundle.main.bundleIdentifier
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != ourBundleID {
            previousFrontmostBundleID = front.bundleIdentifier
        }

        hide(restoringFocus: false)

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let content = IrisPanelHostView()
            .environment(appState)
            .frame(width: frame.width, height: frame.height)

        let hosting = PassThroughHostingController(rootView: content)

        let p = PassThroughPanel(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
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
        p.contentViewController = hosting
        p.setFrame(frame, display: true)

        panel = p
        isShown = true
        isClosing = false

        // Raycast-style: don't activate our app (would visually defocus the
        // user's frontmost window). Just put our panel above everything and
        // make it the key window so keystrokes route to our text field.
        // The other app's title bar stays "active" because we're a
        // non-activating utility panel.
        p.orderFrontRegardless()
        p.makeKey()

        // Outside our window: dismiss but don't consume.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak appState] _ in
            Task { @MainActor in
                appState?.dismiss()
            }
        }

        // Inside our window but outside our content rect: the panel's
        // hit-test returns nil so the click already passes through to the
        // app underneath via the windowserver. But we still need to know
        // about it so we can dismiss — listen at the NSEvent level.
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self, weak appState] event in
            guard let self, let p = self.panel else { return event }
            // If hit-test for this point returns nil, the click is in the
            // pass-through area → dismiss but don't consume the event.
            if let contentView = p.contentView {
                let locInWindow = event.locationInWindow
                let locInView = contentView.convert(locInWindow, from: nil)
                if contentView.hitTest(locInView) == nil {
                    Task { @MainActor in appState?.dismiss() }
                }
            }
            return event
        }
    }

    func hide() {
        hide(restoringFocus: true)
    }

    private func hide(restoringFocus: Bool) {
        if let m = globalMouseMonitor {
            NSEvent.removeMonitor(m)
            globalMouseMonitor = nil
        }
        if let m = localMouseMonitor {
            NSEvent.removeMonitor(m)
            localMouseMonitor = nil
        }

        panel?.orderOut(nil)
        panel?.contentViewController = nil
        panel = nil
        isShown = false
        isClosing = false

        if restoringFocus,
           let ourBundleID = Bundle.main.bundleIdentifier,
           NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ourBundleID,
           let bid = previousFrontmostBundleID,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first {
            // Only re-activate the previous app if we somehow became the
            // frontmost app ourselves; with a non-activating panel this
            // shouldn't happen, but it's a cheap safety net.
            app.activate()
        }
        previousFrontmostBundleID = nil
    }
}

/// Panel that becomes key for typing but lets mouse events pass through
/// any area where the SwiftUI hit-test returns nil.
final class PassThroughPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

/// Hosting controller whose view returns nil from `hitTest(_:)` for any
/// point that doesn't actually hit interactive SwiftUI content, so the
/// window underneath receives the click on the same press.
final class PassThroughHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        super.loadView()
        // The default hosting view returns itself for any point; we need
        // it to return nil when no subview claims the hit.
        // Wrap it in a pass-through container.
        let host = view
        let wrapper = PassThroughContainerView(frame: host.bounds)
        wrapper.autoresizingMask = [.width, .height]
        host.frame = wrapper.bounds
        host.autoresizingMask = [.width, .height]
        wrapper.addSubview(host)
        view = wrapper
    }
}

final class PassThroughContainerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Forward to subviews. If none of them claim it, return nil so the
        // click passes through to the window below.
        for sub in subviews.reversed() {
            let p = convert(point, to: sub)
            if let hit = sub.hitTest(p), hit !== self { return hit }
        }
        return nil
    }
}

/// Wraps the actual panel content and centers it on screen. The empty
/// area around the content is genuinely click-through: it has no
/// hit-testing, so PassThroughContainerView passes the click to the
/// window beneath.
struct IrisPanelHostView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                IrisPanelView()
                    .offset(y: -geo.size.height * 0.10)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}
