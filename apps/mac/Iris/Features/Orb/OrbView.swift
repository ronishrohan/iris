import SwiftUI
import AppKit

struct IrisPanelView: View {
    @Environment(AppState.self) private var appState
    @FocusState private var inputFocused: Bool
    @State private var visible = false
    @State private var observedCloseCounter = 0

    var body: some View {
        VStack(spacing: 12) {
            GlassEffectContainer(spacing: 14) {
                inputRow
            }

            if !appState.latestResponse.isEmpty || isWorking {
                GlassEffectContainer(spacing: 14) {
                    responseView
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity
                            .combined(with: .scale(scale: 0.98, anchor: .top))
                    )
                )
            }
        }
        .frame(width: 640, alignment: .center)
        .fixedSize(horizontal: true, vertical: true)
        .scaleEffect(
            x: visible ? 1.0 : 1.10,
            y: visible ? 1.0 : 1.02,
            anchor: .center
        )
        .opacity(visible ? 1.0 : 0.0)
        .blur(radius: visible ? 0 : 8)
        .onAppear {
            observedCloseCounter = appState.closeRequestCounter
            DispatchQueue.main.async {
                inputFocused = true
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72, blendDuration: 0)) {
                visible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            inputFocused = true
        }
        .onChange(of: appState.closeRequestCounter) { _, newValue in
            guard newValue != observedCloseCounter else { return }
            observedCloseCounter = newValue
            playClose()
        }
        .onExitCommand { appState.dismiss() }
        .animation(.spring(response: 0.32, dampingFraction: 0.78),
                   value: appState.latestResponse.isEmpty)
        .animation(.spring(response: 0.32, dampingFraction: 0.78),
                   value: isWorking)
    }

    private func playClose() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85, blendDuration: 0)) {
            visible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            appState.finishClose()
        }
    }

    private var isWorking: Bool {
        switch appState.phase {
        case .thinking, .toolCalling: return true
        default: return false
        }
    }

    @ViewBuilder
    private var inputRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Ask Iris Something", text: Binding(
                get: { appState.inputText },
                set: { appState.inputText = $0 }
            ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 22, weight: .regular, design: .rounded))
            .foregroundStyle(.primary)
            .focused($inputFocused)
            .lineLimit(1...4)
            .onSubmit { appState.submit() }

            sendButton
                .opacity(appState.inputText.isEmpty ? 0 : 1)
                .allowsHitTesting(!appState.inputText.isEmpty)
                .animation(.easeOut(duration: 0.15), value: appState.inputText.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var sendButton: some View {
        Button {
            appState.submit()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [])
    }

    @ViewBuilder
    private var responseView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !appState.latestResponse.isEmpty {
                ScrollView {
                    MarkdownText(appState.latestResponse)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 240)
            } else if isWorking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(workingLabel)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var workingLabel: String {
        switch appState.phase {
        case .thinking: return "Thinking…"
        case .toolCalling(let n): return "Running \(n)…"
        default: return ""
        }
    }
}

// MARK: - Markdown rendering

/// Renders LLM markdown without pulling in a third-party dependency.
/// Splits on blank lines into block elements (headings, bullet lists,
/// code blocks, paragraphs); each block uses SwiftUI's built-in
/// `AttributedString(markdown:)` for inline formatting (bold, italics,
/// inline code, links).
struct MarkdownText: View {
    let raw: String

    init(_ raw: String) { self.raw = raw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: parsing

    private enum Block {
        case heading(level: Int, text: String)
        case bullet(items: [String])
        case numbered(items: [String])
        case code(text: String)
        case paragraph(text: String)
    }

    private var blocks: [Block] {
        var out: [Block] = []
        let lines = raw.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // fenced code block
            if trimmed.hasPrefix("```") {
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }
                out.append(.code(text: code.joined(separator: "\n")))
                continue
            }

            // heading
            if let h = headingLevel(trimmed) {
                let text = String(trimmed.drop { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                out.append(.heading(level: h, text: text))
                i += 1
                continue
            }

            // bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix("- ") || t.hasPrefix("* ") else { break }
                    items.append(String(t.dropFirst(2)))
                    i += 1
                }
                out.append(.bullet(items: items))
                continue
            }

            // numbered list
            if isNumberedLine(trimmed) {
                var items: [String] = []
                while i < lines.count && isNumberedLine(lines[i].trimmingCharacters(in: .whitespaces)) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if let dot = t.firstIndex(of: ".") {
                        items.append(String(t[t.index(after: dot)...]).trimmingCharacters(in: .whitespaces))
                    }
                    i += 1
                }
                out.append(.numbered(items: items))
                continue
            }

            // blank line -> skip
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // paragraph: consume until blank line
            var para: [String] = [line]
            i += 1
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("```") || t.hasPrefix("#") ||
                    t.hasPrefix("- ") || t.hasPrefix("* ") || isNumberedLine(t) {
                    break
                }
                para.append(lines[i])
                i += 1
            }
            out.append(.paragraph(text: para.joined(separator: " ")))
        }
        return out
    }

    private func headingLevel(_ s: String) -> Int? {
        guard s.hasPrefix("#") else { return nil }
        let hashes = s.prefix { $0 == "#" }.count
        guard hashes >= 1 && hashes <= 6,
              s.count > hashes,
              s[s.index(s.startIndex, offsetBy: hashes)] == " " else { return nil }
        return hashes
    }

    private func isNumberedLine(_ s: String) -> Bool {
        guard let dot = s.firstIndex(of: ".") else { return false }
        let prefix = s[s.startIndex..<dot]
        return !prefix.isEmpty && prefix.allSatisfy(\.isNumber)
    }

    // MARK: rendering

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(.system(size: headingSize(level), weight: .semibold, design: .rounded))

        case .paragraph(let text):
            inline(text)
                .font(.system(size: 16, design: .rounded))

        case .bullet(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        inline(item).font(.system(size: 16, design: .rounded))
                    }
                }
            }

        case .numbered(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).").foregroundStyle(.secondary).monospacedDigit()
                        inline(item).font(.system(size: 16, design: .rounded))
                    }
                }
            }

        case .code(let text):
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.25))
                )
        }
    }

    private func inline(_ s: String) -> Text {
        if let attr = try? AttributedString(
            markdown: s,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return Text(attr)
        }
        return Text(s)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: 22
        case 2: 20
        case 3: 18
        default: 16
        }
    }
}
