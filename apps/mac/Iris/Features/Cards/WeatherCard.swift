import SwiftUI

struct WeatherCard: View {
    let data: WeatherCardData

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.weather") }) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: data.conditionSymbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 38))
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.city)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(data.temperatureText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if let s = data.summary, !s.isEmpty {
                        Text(s)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if let hl = data.highLowText {
                    Text(hl)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
