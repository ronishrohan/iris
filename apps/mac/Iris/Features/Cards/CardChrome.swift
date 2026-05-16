import SwiftUI
import AppKit

/// Common rounded-glass surface shared by every tool result card.
/// Renders the card body and, when an `onOpen` hook is provided, a
/// dedicated "Open" button along the bottom edge — no hover scale,
/// no corner chevron, just an obvious button.
struct CardChrome<Content: View>: View {
    let onOpen: (() -> Void)?
    let openLabel: String
    @ViewBuilder var content: () -> Content

    init(onOpen: (() -> Void)? = nil,
         openLabel: String = "Open",
         @ViewBuilder content: @escaping () -> Content) {
        self.onOpen = onOpen
        self.openLabel = openLabel
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: onOpen == nil ? 0 : 10) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onOpen {
                HStack {
                    Spacer()
                    CardOpenButton(label: openLabel, action: onOpen)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Simple pill button used by every card that deep-links into a
/// system app. Looks like a small native control, no glass / no scale
/// trickery.
struct CardOpenButton: View {
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.regularMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black.opacity(hovering ? 0.45 : 0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.white.opacity(hovering ? 0.14 : 0.08),
                                      lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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
