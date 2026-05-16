import SwiftUI
import AppKit

struct IrisPanelView: View {
    @Environment(AppState.self) private var appState
    @FocusState private var inputFocused: Bool
    @State private var visible = false
    @State private var observedCloseCounter = 0
    @State private var tintProgress: CGFloat = 0
    @State private var hasStartedTint = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseBrightness: Double = 0.0
    @State private var observedPulseCounter = 0
    @State private var frontCardHeight: CGFloat = 0
    @State private var listeningPulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 12) {
            GlassEffectContainer(spacing: 14) {
                inputRow
            }

            responseStack
                .animation(.spring(response: 0.42, dampingFraction: 0.85),
                           value: appState.pastResponses.count)
                .animation(.spring(response: 0.34, dampingFraction: 0.82),
                           value: appState.latestResponse.isEmpty)
                .animation(.spring(response: 0.34, dampingFraction: 0.82),
                           value: appState.latestResponseCard == nil)
                .animation(.spring(response: 0.34, dampingFraction: 0.82),
                           value: isWorking)
                .animation(.spring(response: 0.34, dampingFraction: 0.82),
                           value: isErrored)
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
        .onChange(of: appState.submitPulseCounter) { _, newValue in
            guard newValue != observedPulseCounter else { return }
            observedPulseCounter = newValue
            playSubmitPulse()
        }
        .onChange(of: appState.phase) { _, newPhase in
            // Play the bleed once the assistant finishes responding,
            // mirroring how macOS Siri tints its answer bubble after the
            // response lands.
            if newPhase == .done && !appState.latestResponse.isEmpty && !hasStartedTint {
                hasStartedTint = true
                withAnimation(.spring(response: 1.1, dampingFraction: 0.95)) {
                    tintProgress = 1
                }
            }
        }
        .onChange(of: appState.latestResponse.isEmpty) { _, isEmpty in
            // Reset between turns so the next response replays the bleed.
            if isEmpty {
                tintProgress = 0
                hasStartedTint = false
            }
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

    private func playSubmitPulse() {
        // Tiny equal-sides scale (about 2-3px on a 550pt pill = ~1.005×).
        withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
            pulseScale = 1.005
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                pulseScale = 1.0
            }
        }
    }

    private var isWorking: Bool {
        switch appState.phase {
        case .thinking, .toolCalling: return true
        default: return false
        }
    }

    /// Up to the 3 most recent past responses, newest-last (so newest is
    /// closest to the front card).
    private var visiblePastResponses: [String] {
        Array(appState.pastResponses.suffix(3))
    }

    private var hasFrontCard: Bool {
        !appState.latestResponse.isEmpty
            || appState.latestResponseCard != nil
            || isWorking
            || isErrored
    }

    @ViewBuilder
    private var responseStack: some View {
        if hasFrontCard || !appState.pastResponses.isEmpty {
            ZStack(alignment: .top) {
                // Front (newest) card at the top of the stack. We measure
                // its height so past cards can sit right under its
                // bottom edge — each past card peeking out by a few px
                // more than the one in front of it.
                if hasFrontCard {
                    frontResponseCard
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: FrontCardHeightKey.self,
                                    value: geo.size.height
                                )
                            }
                        )
                        .zIndex(0)
                }

                // Past responses laid out below the front card's bottom
                // edge. Newest-past sits closest to the front; older
                // ones peek out a little further down.
                ForEach(Array(visiblePastResponses.enumerated().reversed()), id: \.offset) { pair in
                    let stackIndex = pair.offset
                    let text = pair.element
                    // depth = 1 for the card immediately behind the
                    // front, 2 for the one behind that, etc.
                    let depth = visiblePastResponses.count - stackIndex
                    pastResponseCard(text: text, depth: depth)
                        .zIndex(Double(-depth))
                }
            }
            .onPreferenceChange(FrontCardHeightKey.self) { h in
                frontCardHeight = h
            }
        }
    }

    private var frontResponseCard: some View {
        GlassEffectContainer(spacing: 14) {
            responseView
                .background(
                    ResponseBleedTint(progress: tintProgress, cornerRadius: 20)
                )
                .background(
                    Color.black.opacity(0.24),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
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

    /// `depth` is 1 for the card directly behind the front one, 2 for
    /// the one behind that, etc. The card sits below the front card's
    /// bottom edge — its top is at `frontCardHeight - overlap`, so only
    /// a thin "peek" of it is visible. Each deeper card pokes out a
    /// little more than the one above.
    private func pastResponseCard(text: String, depth: Int) -> some View {
        // How much of the card pokes out below the one in front of it.
        let peek: CGFloat = 14
        // How much of itself sits hidden behind the card above.
        let overlap: CGFloat = 22
        // Total y offset from the top of the ZStack.
        let yOffset = max(0, frontCardHeight - overlap) + CGFloat(depth - 1) * peek
        let scale = max(0.86, 1.0 - CGFloat(depth) * 0.03)
        let textOpacity = max(0.20, 1.0 - Double(depth) * 0.30)
        return Text(text)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.primary.opacity(textOpacity))
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(scale, anchor: .top)
            .offset(y: yOffset)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var isErrored: Bool {
        if case .error = appState.phase { return true }
        return false
    }

    private var errorMessage: String? {
        if case .error(let msg) = appState.phase { return msg }
        return nil
    }

    @ViewBuilder
    private var inputRow: some View {
        HStack(spacing: 12) {
            micToggle

            TextField(textFieldPlaceholder,
                      text: Binding(
                        get: { appState.inputText },
                        set: { appState.inputText = $0 }
                      ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 22, weight: .regular, design: .rounded))
            .foregroundStyle(.primary)
            .focused($inputFocused)
            .lineLimit(1...4)
            .disabled(isWorking)
            .opacity(isWorking ? 0.55 : 1.0)
            .onSubmit {
                guard !isWorking else { return }
                appState.submit()
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 18)
        .padding(.vertical, 7)
        // Listening nebula: shader-driven semi-transparent black smoke
        // with sparse warm clusters, masked into the leading edge of
        // the pill while voice mode is active.
        .background(
            MicListeningTint(
                active: appState.voiceMode || appState.isListening,
                amplitude: appState.micAmplitude
            )
        )
        // Black tint between content and glass to push the pill toward
        // a dark frosted look regardless of what's behind the panel.
        .background(Color.black.opacity(0.22), in: Capsule())
        .glassEffect(.regular.interactive(), in: .capsule)
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(pulseScale, anchor: .center)
    }

    private var textFieldPlaceholder: String {
        if isWorking { return "Working…" }
        // Stay on "Listening…" whenever we're in voice mode, even
        // briefly between turns while the dictation engine is being
        // re-armed. Without this, the placeholder flickers back to
        // "Ask Iris Something" for a frame before re-arming.
        if appState.voiceMode || appState.isListening { return "Listening…" }
        return "Ask Iris Something"
    }

    private var micToggle: some View {
        Button {
            guard !isWorking else { return }
            appState.toggleMic()
        } label: {
            Image(systemName: "mic")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    appState.isListening
                        ? AnyShapeStyle(Color.white)
                        : AnyShapeStyle(.secondary)
                )
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.2), value: appState.isListening)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .opacity(isWorking ? 0.55 : 1.0)
        .help(appState.isListening ? "Stop listening" : "Start voice input")
    }

    /// True when the only thing inside the response view is a rich
    /// card (no prose, no error, no spinner). We collapse the outer
    /// padding in that case so the card's own padding is what we see.
    private var responseShowsOnlyCard: Bool {
        appState.latestResponseCard != nil
            && appState.latestResponse.isEmpty
            && errorMessage == nil
            && !isWorking
    }

    @ViewBuilder
    private var responseView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red.opacity(0.85))
                        .font(.system(size: 14, weight: .semibold))
                    Text(err)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            } else {
                if let card = appState.latestResponseCard {
                    ResponseCardHost(ui: card)
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .move(edge: .top))
                                    .combined(with: .scale(scale: 0.96, anchor: .top)),
                                removal: .opacity
                            )
                        )
                }
                if !appState.latestResponse.isEmpty {
                    ResponseScrollBody(text: appState.latestResponse)
                }
            }
            if isWorking && errorMessage == nil &&
               appState.latestResponse.isEmpty && appState.latestResponseCard == nil {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(workingLabel)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, responseShowsOnlyCard ? 4 : 16)
        .padding(.vertical, responseShowsOnlyCard ? 4 : 12)
    }

    private var workingLabel: String {
        switch appState.phase {
        case .thinking: return "Thinking…"
        case .toolCalling(let n): return "\(ToolLabel.friendly(n))…"
        default: return ""
        }
    }
}

// MARK: - Markdown rendering

/// Renders LLM markdown without pulling in a third-party dependency.
/// Splits on blank lines into block elements (headings, bullet lists,
/// Wraps the streaming markdown body in a ScrollView only when the
/// content is taller than the visible cap. Short replies render at
/// their natural intrinsic height with no extra slack below the text;
/// long replies scroll inside the cap. Without this the ScrollView
/// would always grab `maxHeight`, leaving a fat empty band beneath
/// short answers.
struct ResponseScrollBody: View {
    let text: String
    private let cap: CGFloat = 240
    private let fadeHeight: CGFloat = 24
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    /// True only when the content is taller than the visible cap.
    private var overflows: Bool { contentHeight > cap + 0.5 }
    /// Visible window height — natural for short content, capped for long.
    private var visibleHeight: CGFloat { min(contentHeight, cap) }
    /// How far we've scrolled from the top (0 at top, > 0 once scrolled).
    private var scrolledFromTop: CGFloat { max(0, -scrollOffset) }
    /// How far the bottom edge of the content is from the visible bottom.
    private var remainingBelow: CGFloat {
        max(0, contentHeight - visibleHeight - scrolledFromTop)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                MarkdownText(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ResponseBodyHeightKey.self,
                                            value: geo.size.height)
                                .preference(key: ResponseScrollOffsetKey.self,
                                            value: geo.frame(in: .named("iris.response.scroll")).minY)
                        }
                    )
                    .id("iris.response.body")
                Color.clear
                    .frame(height: 1)
                    .id("iris.response.bottom")
            }
            .coordinateSpace(name: "iris.response.scroll")
            .frame(height: visibleHeight, alignment: .top)
            .mask(scrollMask)
            .onPreferenceChange(ResponseBodyHeightKey.self) { h in
                contentHeight = h
            }
            .onPreferenceChange(ResponseScrollOffsetKey.self) { y in
                scrollOffset = y
            }
            .onChange(of: text) { _, _ in
                // Only follow the tail of the stream when content
                // actually overflows the visible window. Short replies
                // never need a scroll — letting it fire on them creates
                // a tiny up-then-down jiggle on first render.
                guard overflows else { return }
                withAnimation(.linear(duration: 0.12)) {
                    proxy.scrollTo("iris.response.bottom", anchor: .bottom)
                }
            }
        }
    }

    /// Soft fade mask: opaque in the middle, fades to transparent at
    /// the top/bottom edges when there's hidden content in that
    /// direction. Returns a fully opaque mask if content doesn't
    /// overflow.
    @ViewBuilder
    private var scrollMask: some View {
        if overflows {
            let topFade    = min(1, scrolledFromTop / fadeHeight)
            let bottomFade = min(1, remainingBelow / fadeHeight)
            let topAlpha:    Double = 1.0 - 0.95 * topFade
            let bottomAlpha: Double = 1.0 - 0.95 * bottomFade
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(topAlpha),    location: 0.0),
                    .init(color: .white,                      location: fadeHeight / max(visibleHeight, 1)),
                    .init(color: .white,                      location: 1.0 - fadeHeight / max(visibleHeight, 1)),
                    .init(color: .white.opacity(bottomAlpha), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color.white
        }
    }
}

private struct ResponseBodyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

private struct ResponseScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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

// MARK: - Preference keys

private struct FrontCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

// MARK: - Legacy bleed tint (unused)

/// Retained as a thin wrapper around the live `ResponseBleedTint` /
/// `NebulaView` for backwards compatibility with anything that might
/// still reference the name. New code should call `ResponseBleedTint`
/// directly.
struct SiriBleedTint: View {
    let progress: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ResponseBleedTint(progress: progress, cornerRadius: cornerRadius)
    }
}

/// Listening tint for the input pill. Wraps the Metal-shader
/// `NebulaView` in a left-to-right reveal mask + capsule clip, fades
/// in / out with `active`, and scales the shader intensity by mic
/// amplitude.
struct MicListeningTint: View {
    let active: Bool
    let amplitude: Float

    @State private var enterProgress: CGFloat = 0
    @State private var exitProgress: CGFloat = 0
    @State private var shouldRender: Bool = false

    var body: some View {
        Group {
            if shouldRender {
                tintBody
            } else {
                Color.clear
            }
        }
        .onAppear {
            // Make sure nothing is drawn on first mount.
            shouldRender = active
        }
        .onChange(of: active) { _, isActive in
            if isActive {
                shouldRender = true
                enterProgress = 0
                exitProgress = 1
                withAnimation(.easeOut(duration: 0.9)) {
                    enterProgress = 1.0
                }
            } else {
                withAnimation(.easeIn(duration: 0.25)) {
                    exitProgress = 0
                    enterProgress = 0
                }
                // Stop rendering after the fade-out completes.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    if !active { shouldRender = false }
                }
            }
        }
    }

    @ViewBuilder
    private var tintBody: some View {
        // Idle mic still has a clearly visible baseline; voice
        // amplitude pushes intensity toward full AND drives the
        // shader-side drift speed + brightness.
        let amp = max(0, min(1, Double(amplitude)))
        let intensity = Float(0.80 + amp * 0.20)
        NebulaView(intensity: intensity, amp: Float(amp))
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white, location: max(0.0, enterProgress - 0.15)),
                        .init(color: .white.opacity(0.0), location: enterProgress)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .allowsHitTesting(false)
            .opacity(Double(exitProgress))
    }
}

/// Nebula tint for the response card. Uses the same Metal shader as
/// `MicListeningTint` but the reveal mask is an expanding circle that
/// bleeds in from the top edge as `progress` goes 0 → 1.
struct ResponseBleedTint: View {
    let progress: CGFloat
    let cornerRadius: CGFloat

    @State private var shouldRender: Bool = false

    var body: some View {
        Group {
            if shouldRender || progress > 0 {
                tintBody
            } else {
                Color.clear
            }
        }
        .onAppear { shouldRender = progress > 0 }
        .onChange(of: progress) { _, p in
            if p > 0 {
                shouldRender = true
            } else {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    if progress == 0 { shouldRender = false }
                }
            }
        }
    }

    @ViewBuilder
    private var tintBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            NebulaView(intensity: 1.0)
                .mask(
                    Circle()
                        .frame(
                            width: revealDiameter(w: w, h: h) * progress,
                            height: revealDiameter(w: w, h: h) * progress
                        )
                        .position(x: w * 0.5, y: 0)
                        .blur(radius: 14)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
                .opacity(min(0.95, Double(progress) + 0.1))
        }
    }

    /// Diameter of the reveal circle large enough to cover the card from
    /// the top-center anchor — i.e. twice the corner distance.
    private func revealDiameter(w: CGFloat, h: CGFloat) -> CGFloat {
        let cornerDistance = sqrt((w * 0.5) * (w * 0.5) + h * h)
        return cornerDistance * 2 * 1.1
    }
}
