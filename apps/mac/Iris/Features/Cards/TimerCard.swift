import SwiftUI

struct TimerCard: View {
    let data: TimerCardData

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.clock") }) {
            HStack(alignment: .center, spacing: 16) {
                ringView
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                        Text(remainingText(now: ctx.date))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    Text(totalLine)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                CardOpenChevron()
            }
        }
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 4)
                .frame(width: 44, height: 44)
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                let f = max(0, min(1, fractionRemaining(now: ctx.date)))
                Circle()
                    .trim(from: 0, to: CGFloat(f))
                    .stroke(
                        AngularGradient(
                            colors: [.orange, .red, .orange],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: f)
            }
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }

    private func remainingText(now: Date) -> String {
        let s = max(0, Int(data.fireDate.timeIntervalSince(now).rounded()))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    private func fractionRemaining(now: Date) -> Double {
        guard data.totalSeconds > 0 else { return 0 }
        let remaining = max(0, data.fireDate.timeIntervalSince(now))
        return remaining / data.totalSeconds
    }

    private var totalLine: String {
        let s = Int(data.totalSeconds.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if sec > 0 && h == 0 { parts.append("\(sec)s") }
        return "Set for " + parts.joined(separator: " ")
    }
}
