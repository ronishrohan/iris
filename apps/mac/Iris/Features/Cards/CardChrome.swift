import SwiftUI
import AppKit

/// Common rounded-glass surface shared by every tool result card.
/// Provides padding, a soft border, a content-shape so the whole card
/// is tappable, and an optional `onOpen` hook that lets the card act
/// like a Siri snippet — tap anywhere to jump into the relevant
/// system app.
struct CardChrome<Content: View>: View {
    let onOpen: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @State private var hovering = false

    init(onOpen: (() -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.onOpen = onOpen
        self.content = content
    }

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onHover { hovering = $0 }
            .scaleEffect(hovering && onOpen != nil ? 1.005 : 1.0)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onTapGesture {
                onOpen?()
            }
            .help(onOpen != nil ? "Open in app" : "")
    }
}

/// A small "open in app" chevron used in the trailing edge of cards so
/// the user notices the card is tappable.
struct CardOpenChevron: View {
    var body: some View {
        Image(systemName: "arrow.up.forward.app.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary.opacity(0.6))
    }
}

// MARK: - Shared helpers

enum CardColor {
    /// Parse "#RRGGBB" or "#RRGGBBAA". Returns nil on a bad input.
    static func from(hex: String?) -> Color? {
        guard let hex else { return nil }
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
              let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xff) / 255
            g = Double((v >> 8) & 0xff) / 255
            b = Double(v & 0xff) / 255
            a = 1
        } else {
            r = Double((v >> 24) & 0xff) / 255
            g = Double((v >> 16) & 0xff) / 255
            b = Double((v >> 8) & 0xff) / 255
            a = Double(v & 0xff) / 255
        }
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

/// Wrapper around NSWorkspace.open so cards can deep-link with a
/// single line.
enum CardDeepLink {
    @MainActor
    static func open(_ url: String) {
        guard let u = URL(string: url) else { return }
        NSWorkspace.shared.open(u)
    }

    @MainActor
    static func openApp(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    static func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
