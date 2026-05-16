import SwiftUI

struct ReminderCard: View {
    let data: ReminderCardData

    var body: some View {
        CardChrome(onOpen: { open() }) {
            HStack(alignment: .center, spacing: 14) {
                listDot
                VStack(alignment: .leading, spacing: 3) {
                    Text(data.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(detailLine)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                CardOpenChevron()
            }
        }
    }

    private var listDot: some View {
        Circle()
            .fill(CardColor.from(hex: data.listColorHex) ?? Color.orange)
            .frame(width: 14, height: 14)
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
    }

    private var detailLine: String {
        var parts: [String] = []
        if let list = data.listName, !list.isEmpty { parts.append(list) }
        if let due = data.due {
            parts.append(Self.dateFmt.string(from: due))
        }
        if parts.isEmpty { return "Added to Reminders" }
        return parts.joined(separator: "  •  ")
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func open() {
        // Deep-link to a specific reminder by its calendar-item ID when
        // we have it; otherwise just open the Reminders app.
        if let id = data.calendarItemIdentifier,
           let url = URL(string: "x-apple-reminderkit://REMCDReminder/\(id)") {
            CardDeepLink.open(url.absoluteString)
            return
        }
        CardDeepLink.openApp(bundleID: "com.apple.reminders")
    }
}

struct ReminderListCard: View {
    let items: [ReminderCardData]

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.reminders") }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checklist")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Reminders")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    CardOpenChevron()
                }
                ForEach(Array(items.prefix(5).enumerated()), id: \.offset) { _, r in
                    HStack(alignment: .center, spacing: 10) {
                        Circle()
                            .fill(CardColor.from(hex: r.listColorHex) ?? Color.orange)
                            .frame(width: 10, height: 10)
                        Text(r.title)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let due = r.due {
                            Text(Self.dueFmt.string(from: due))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if items.count > 5 {
                    Text("+\(items.count - 5) more")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private static let dueFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()
}
