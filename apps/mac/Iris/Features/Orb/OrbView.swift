import SwiftUI

struct OrbView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 16) {
                AnimatedOrb(phase: appState.phase)
                    .frame(width: 96, height: 96)

                Text(displayText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
            }
            .padding(20)
        }
    }

    private var displayText: String {
        if !appState.latestResponse.isEmpty { return appState.latestResponse }
        if !appState.latestTranscript.isEmpty { return appState.latestTranscript }
        switch appState.phase {
        case .idle: return "Tap ⌥-Space to talk."
        case .wakeDetected: return "Yes?"
        case .listening: return "Listening…"
        case .transcribing: return "…"
        case .thinking: return "Thinking…"
        case .toolCalling(let n): return "Running \(n)…"
        case .speaking: return ""
        case .error(let m): return m
        }
    }
}

struct AnimatedOrb: View {
    let phase: AppState.Phase
    @State private var pulse: CGFloat = 0.9

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.purple, .blue, .pink, .purple],
                        center: .center
                    )
                )
                .blur(radius: 8)
                .scaleEffect(pulse)
                .opacity(0.9)

            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
        .onAppear { animate() }
        .onChange(of: phase) { _, _ in animate() }
    }

    private func animate() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            pulse = isActive ? 1.05 : 0.92
        }
    }

    private var isActive: Bool {
        switch phase {
        case .idle, .error: false
        default: true
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
