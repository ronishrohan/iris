import SwiftUI
import AppKit

/// Common dark-glass shell shared by every tool result card. Each
/// card now ships its own container — rounded `.regularMaterial`
/// pushed dark by a tinted overlay, a thin white hairline border, and
/// (when the card can be deep-linked) a small `Open` action pinned to
/// the top-right corner of the card body. No bottom action row.
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

    private var cornerRadius: CGFloat { 18 }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            // Leave room at the top-right for the Open chip so it
            // never crowds the card's own content.
            .padding(.trailing, onOpen == nil ? 14 : 64)
            .padding(.leading, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if let onOpen {
                    CardOpenButton(label: openLabel, action: onOpen)
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Small pill button anchored in the card's top-right corner. Quiet
/// black-glass surface so it reads as a secondary action, not as the
/// card's primary content.
struct CardOpenButton: View {
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(hovering ? 1.0 : 0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(hovering ? 0.55 : 0.40))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(hovering ? 0.18 : 0.10),
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
