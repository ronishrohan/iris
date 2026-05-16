import AppKit

/// Detects a "double-tap" of a single modifier key (e.g. double-Option).
///
/// macOS doesn't expose a native API for this, so we observe global
/// `.flagsChanged` events and look for: modifier down → up → down → up
/// all within a short window (~350 ms), with no other keys / modifiers
/// in between.
///
/// We need BOTH global and local NSEvent monitors because the global
/// one fires only when our app isn't frontmost, while the local one
/// fires only when it is. Iris uses a non-activating panel so we want
/// the trigger to work in both states.
@MainActor
final class DoubleTapModifier {
    /// Which modifier mask to watch. Default: ⌥ (Option / Alt).
    var modifier: NSEvent.ModifierFlags = .option

    /// Max time between the first key-up and the second key-down for
    /// the gesture to count as a double-tap.
    var window: TimeInterval = 0.35

    /// Called on the main actor when the gesture fires.
    var onTrigger: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var lastUpAt: Date = .distantPast
    private var modifierIsDown = false

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        // Mask out everything except the modifier we care about.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let onlyTarget = flags == modifier
        let nothingDown = flags.rawValue == 0

        if onlyTarget && !modifierIsDown {
            // KEY DOWN edge for our modifier.
            modifierIsDown = true
            let elapsed = Date().timeIntervalSince(lastUpAt)
            if elapsed <= window {
                // Second press within the window → fire!
                lastUpAt = .distantPast
                modifierIsDown = false
                onTrigger?()
            }
        } else if nothingDown && modifierIsDown {
            // KEY UP edge for our modifier with nothing else down.
            modifierIsDown = false
            lastUpAt = Date()
        } else {
            // Some other modifier or key combo: reset the gesture so
            // ⌥⌘ etc. doesn't count toward a future ⌥⌥.
            modifierIsDown = false
            lastUpAt = .distantPast
        }
    }
}
