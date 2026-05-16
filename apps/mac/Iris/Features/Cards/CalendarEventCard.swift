import SwiftUI

struct CalendarEventCard: View {
    let data: CalendarEventCardData

    var body: some View {
        CardChrome(onOpen: { open() }) {
            HStack(alignment: .top, spacing: 14) {
                colorStripe
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(timeLine)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if let loc = data.location, !loc.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            Text(loc)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                CardOpenChevron()
            }
        }
    }

    private var colorStripe: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(CardColor.from(hex: data.calendarColorHex) ?? Color.red)
            .frame(width: 4)
    }

    private var timeLine: String {
        let f = Self.fmt
        let startStr = f.string(from: data.start)
        if let end = data.end {
            let timeOnly = Self.timeFmt
            return "\(startStr) – \(timeOnly.string(from: end))"
        }
        return startStr
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private func open() {
        // ical:// jumps to a date; Apple's deep-link to a specific event
        // isn't a stable public scheme, so we open Calendar to the
        // event's day instead.
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: data.start)
        if let y = comps.year, let m = comps.month, let d = comps.day {
            let s = String(format: "ical://%04d%02d%02d", y, m, d)
            CardDeepLink.open(s)
            return
        }
        CardDeepLink.openApp(bundleID: "com.apple.iCal")
    }
}

struct CalendarEventListCard: View {
    let items: [CalendarEventCardData]

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.iCal") }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Upcoming")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    CardOpenChevron()
                }
                ForEach(Array(items.prefix(5).enumerated()), id: \.offset) { _, ev in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(CardColor.from(hex: ev.calendarColorHex) ?? Color.red)
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ev.title)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(Self.fmt.string(from: ev.start))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                }
                if items.count > 5 {
                    Text("+\(items.count - 5) more")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
