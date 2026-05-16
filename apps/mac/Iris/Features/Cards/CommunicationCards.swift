import SwiftUI

// MARK: - Music

struct MusicCard: View {
    let data: MusicCardData

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.Music") }) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [.pink, .purple],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.action)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    if let t = data.title, !t.isEmpty {
                        Text(t)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    if let a = data.artist, !a.isEmpty {
                        Text(a)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                CardOpenChevron()
            }
        }
    }
}

// MARK: - Contact

struct ContactCard: View {
    let data: ContactCardData

    var body: some View {
        CardChrome(onOpen: {
            CardDeepLink.openApp(bundleID: "com.apple.AddressBook")
        }) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .indigo],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 44, height: 44)
                    Text(data.initials)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(data.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let p = data.primaryPhone, !p.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(p)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let e = data.primaryEmail, !e.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(e)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                CardOpenChevron()
            }
        }
    }
}

// MARK: - Message Sent

struct MessageSentCard: View {
    let data: MessageSentCardData

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.MobileSMS") }) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Sent")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(data.recipient)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text(data.preview)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                CardOpenChevron()
            }
        }
    }
}

// MARK: - Email Sent

struct EmailSentCard: View {
    let data: EmailSentCardData

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.mail") }) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 36, height: 36)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Sent to")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(data.recipient)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(data.subject)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let p = data.preview, !p.isEmpty {
                        Text(p)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                CardOpenChevron()
            }
        }
    }
}
