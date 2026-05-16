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
        !appState.latestResponse.isEmpty || isWorking || isErrored
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
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
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
        // Listening nebula: bleeds in from the left of the input pill,
        // sweeps right while gently shifting hues. Speed reacts to the
        // current mic amplitude. We keep it active while the user is in
        // voice mode (not just while the dictation engine is up) so it
        // doesn't blink off between turns.
        .background(
            MicListeningTint(
                active: appState.voiceMode || appState.isListening,
                amplitude: appState.micAmplitude
            )
        )
        .glassEffect(.regular.interactive(), in: .capsule)
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
                        ? AnyShapeStyle(LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(.secondary)
                )
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
                .animation(.easeInOut(duration: 0.2), value: appState.isListening)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .opacity(isWorking ? 0.55 : 1.0)
        .help(appState.isListening ? "Stop listening" : "Start voice input")
    }

    @ViewBuilder
    private var responseView: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            } else if !appState.latestResponse.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        MarkdownText(appState.latestResponse)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id("iris.response.body")
                            .background(
                                // Sentinel pinned to the very bottom that
                                // we scroll to whenever the stream grows.
                                GeometryReader { _ in Color.clear }
                            )
                        Color.clear
                            .frame(height: 1)
                            .id("iris.response.bottom")
                    }
                    .frame(maxHeight: 240)
                    .onChange(of: appState.latestResponse) { _, _ in
                        // Keep the newest streamed text in view. Use
                        // `.bottom` so we follow the tail of the stream
                        // rather than yanking back to the top.
                        withAnimation(.linear(duration: 0.12)) {
                            proxy.scrollTo("iris.response.bottom", anchor: .bottom)
                        }
                    }
                }
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

// MARK: - Preference keys

private struct FrontCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

// MARK: - Siri-style bleed tint

/// Colored tint that "bleeds" into the response card from the top —
/// matches the effect macOS Siri uses when its answer arrives. A circular
/// mask anchored at the top expands outward; the mask edge is feathered
/// (`.blur`) so it looks soft. The tint itself is a nebula of overlapping
/// radial-gradient blobs that drift slowly so it never looks like a flat
/// gradient. The whole thing is clipped to the same rounded rect as the
/// host card so it can't bleed outside the corner radius.
struct SiriBleedTint: View {
    let progress: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Radius large enough to fully cover at progress = 1.
            let maxRadius = sqrt(w * w + h * h) * 1.1
            let radius = max(0.0001, maxRadius * progress)

            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                ZStack {
                    NebulaBlob(color: Color(red: 0.20, green: 0.78, blue: 0.62), // teal-green
                               cx: 0.28 + 0.05 * sin(t * 0.45),
                               cy: 0.30 + 0.04 * cos(t * 0.55),
                               sizeFactor: 0.95,
                               alpha: 0.28,
                               w: w, h: h)
                    NebulaBlob(color: Color(red: 0.25, green: 0.55, blue: 0.95), // royal blue
                               cx: 0.72 + 0.06 * cos(t * 0.35),
                               cy: 0.35 + 0.05 * sin(t * 0.50),
                               sizeFactor: 0.90,
                               alpha: 0.26,
                               w: w, h: h)
                    NebulaBlob(color: Color(red: 0.20, green: 0.70, blue: 1.00), // sky blue
                               cx: 0.45 + 0.08 * sin(t * 0.55 + 1.3),
                               cy: 0.70 + 0.05 * cos(t * 0.40 + 0.7),
                               sizeFactor: 1.05,
                               alpha: 0.24,
                               w: w, h: h)
                    NebulaBlob(color: Color(red: 0.40, green: 0.85, blue: 0.55), // mint
                               cx: 0.20 + 0.06 * cos(t * 0.30 + 0.4),
                               cy: 0.78 + 0.04 * sin(t * 0.45 + 1.1),
                               sizeFactor: 0.80,
                               alpha: 0.22,
                               w: w, h: h)
                    NebulaBlob(color: Color(red: 0.30, green: 0.65, blue: 0.80), // cyan-teal
                               cx: 0.85 + 0.05 * sin(t * 0.40 + 2.1),
                               cy: 0.65 + 0.05 * cos(t * 0.35 + 1.6),
                               sizeFactor: 0.75,
                               alpha: 0.20,
                               w: w, h: h)
                }
                .blur(radius: 22)
                .blendMode(.plusLighter)
            }
            .mask(
                Circle()
                    .frame(width: radius * 2, height: radius * 2)
                    .position(x: w * 0.5, y: 0)
                    .blur(radius: 14)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
            .opacity(min(0.7, Double(progress)))
        }
    }
}

/// Animated nebula that lives inside the input pill while voice mode is
/// active. It bleeds in from the left edge, sweeps right, and gently
/// shifts hue over time. Renders absolutely nothing when not active, so
/// it can't flicker on first panel show.
///
/// `amplitude` (0...1, smoothed mic level) accelerates the underlying
/// drift so the nebula visibly reacts to the user's voice: a quiet idle
/// state breathes; loud speech sweeps faster.
struct MicListeningTint: View {
    let active: Bool
    let amplitude: Float

    @State private var enterProgress: CGFloat = 0
    @State private var exitProgress: CGFloat = 0   // fades out the running tint
    @State private var shouldRender: Bool = false  // gates rendering entirely
    /// Integrated "voice phase" — we advance this instead of relying on
    /// the wall-clock so the perceived animation speed actually scales
    /// with `amplitude`. Lives in @State so it persists across
    /// TimelineView ticks.
    @State private var voicePhase: Double = 0
    @State private var lastTick: Date = .now

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
                // Restart the phase clock so dt doesn't include the gap
                // since the tint was last visible.
                lastTick = .now
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

    /// Advance the voice-driven phase and return the value to render at
    /// for this tick. Schedules the @State update via DispatchQueue so
    /// we don't mutate state inside a view body.
    private func advanceVoicePhase(now: Date) -> Double {
        let amp = max(0, min(1, Double(amplitude)))
        let speed = 1.0 + amp * 5.0
        let dt = now.timeIntervalSince(lastTick)
        let safeDt = min(max(0, dt), 0.1)
        let next = voicePhase + safeDt * speed
        DispatchQueue.main.async {
            voicePhase = next
            lastTick = now
        }
        return next
    }

    @ViewBuilder
    private var tintBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            TimelineView(.animation) { ctx in
                let t = advanceVoicePhase(now: ctx.date)
                let hueOffset = t.truncatingRemainder(dividingBy: 24) / 24.0
                let c1 = Color(hue: (0.78 + hueOffset).truncatingRemainder(dividingBy: 1),
                               saturation: 0.85, brightness: 1.0)
                let c2 = Color(hue: (0.62 + hueOffset).truncatingRemainder(dividingBy: 1),
                               saturation: 0.90, brightness: 1.0)
                let c3 = Color(hue: (0.45 + hueOffset).truncatingRemainder(dividingBy: 1),
                               saturation: 0.85, brightness: 1.0)

                ZStack {
                    NebulaBlob(color: c1,
                               cx: 0.12 + 0.10 * sin(t * 0.55),
                               cy: 0.50 + 0.16 * cos(t * 0.40),
                               sizeFactor: 0.55,
                               alpha: 0.55,
                               w: w, h: h)
                    NebulaBlob(color: c2,
                               cx: 0.32 + 0.10 * cos(t * 0.45 + 1.1),
                               cy: 0.55 + 0.15 * sin(t * 0.50 + 0.6),
                               sizeFactor: 0.50,
                               alpha: 0.50,
                               w: w, h: h)
                    NebulaBlob(color: c3,
                               cx: 0.55 + 0.12 * sin(t * 0.35 + 2.0),
                               cy: 0.50 + 0.20 * cos(t * 0.45 + 1.3),
                               sizeFactor: 0.55,
                               alpha: 0.45,
                               w: w, h: h)
                }
                .compositingGroup()
                .blur(radius: 20)
                .drawingGroup(opaque: false)
                .blendMode(.plusLighter)
            }
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
}

/// Nebula tint for the response card. Same hue-cycling blob palette as
/// MicListeningTint, but the reveal mask bleeds in from the top edge
/// downward, growing as `progress` goes 0 → 1.
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

            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let hueOffset = t.truncatingRemainder(dividingBy: 24) / 24.0
                let c1 = Color(hue: (0.78 + hueOffset).truncatingRemainder(dividingBy: 1),
                               saturation: 0.85, brightness: 1.0)
                let c2 = Color(hue: (0.62 + hueOffset).truncatingRemainder(dividingBy: 1),
                               saturation: 0.90, brightness: 1.0)
                let c3 = Color(hue: (0.45 + hueOffset).truncatingRemainder(dividingBy: 1),
                               saturation: 0.85, brightness: 1.0)

                ZStack {
                    NebulaBlob(color: c1,
                               cx: 0.30 + 0.10 * sin(t * 0.55),
                               cy: 0.18 + 0.10 * cos(t * 0.40),
                               sizeFactor: 0.85,
                               alpha: 0.45,
                               w: w, h: h)
                    NebulaBlob(color: c2,
                               cx: 0.65 + 0.10 * cos(t * 0.45 + 1.1),
                               cy: 0.22 + 0.10 * sin(t * 0.50 + 0.6),
                               sizeFactor: 0.80,
                               alpha: 0.42,
                               w: w, h: h)
                    NebulaBlob(color: c3,
                               cx: 0.50 + 0.12 * sin(t * 0.35 + 2.0),
                               cy: 0.12 + 0.08 * cos(t * 0.45 + 1.3),
                               sizeFactor: 0.90,
                               alpha: 0.38,
                               w: w, h: h)
                }
                .compositingGroup()
                .blur(radius: 22)
                .drawingGroup(opaque: false)
                .blendMode(.plusLighter)
            }
            // Circular reveal expanding from the top center. The circle
            // has to be big enough at progress=1 to fully cover the card
            // (corner-to-corner diagonal from the top-center point).
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
            .opacity(min(0.85, Double(progress) + 0.1))
        }
    }

    /// Diameter of the reveal circle large enough to cover the card from
    /// the top-center anchor — i.e. twice the corner distance.
    private func revealDiameter(w: CGFloat, h: CGFloat) -> CGFloat {
        let cornerDistance = sqrt((w * 0.5) * (w * 0.5) + h * h)
        return cornerDistance * 2 * 1.1
    }
}

private struct NebulaBlob: View {
    let color: Color
    let cx: Double
    let cy: Double
    let sizeFactor: Double
    let alpha: Double
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        let radius = max(w, h) * CGFloat(sizeFactor)
        return RadialGradient(
            gradient: Gradient(stops: [
                .init(color: color.opacity(alpha), location: 0.0),
                .init(color: color.opacity(alpha * 0.55), location: 0.4),
                .init(color: color.opacity(0.0), location: 1.0)
            ]),
            center: UnitPoint(x: cx, y: cy),
            startRadius: 0,
            endRadius: radius
        )
    }
}
