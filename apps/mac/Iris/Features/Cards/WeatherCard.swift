import SwiftUI

struct WeatherCard: View {
    let data: WeatherCardData

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.weather") }) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: city tag.
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(data.city.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.4)
                        .lineLimit(1)
                }

                // Hero row: glyph + temperature side-by-side.
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Image(systemName: data.conditionSymbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.primary)
                        .font(.system(size: 44, weight: .light))
                        .frame(width: 50, alignment: .leading)
                    Text(data.temperatureText)
                        .font(.system(size: 56, weight: .thin, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }

                // Bottom row: condition summary + high/low chip.
                HStack(spacing: 8) {
                    if let s = data.summary, !s.isEmpty {
                        Text(s)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let hl = data.highLowText {
                        Text(hl)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }
            }
        }
    }
}
