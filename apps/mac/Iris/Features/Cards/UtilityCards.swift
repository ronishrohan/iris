import SwiftUI

// MARK: - Calculation

struct CalculationCard: View {
    let data: CalculationCardData

    var body: some View {
        CardChrome(onOpen: nil) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.expression)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(data.result)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }
}

// MARK: - World Clock

struct WorldClockCard: View {
    let data: WorldClockCardData

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.clock") }) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: data.isDaytime ? "sun.max.fill" : "moon.stars.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 28))
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.city)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(data.timeText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    if let d = data.dateText {
                        Text(d)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
            }
        }
    }
}

// MARK: - Note

struct NoteCard: View {
    let data: NoteCardData

    var body: some View {
        CardChrome(onOpen: { CardDeepLink.openApp(bundleID: "com.apple.Notes") }) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 32, height: 38)
                    Image(systemName: "note.text")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved to Notes")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(data.preview)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                    if let f = data.folder, !f.isEmpty {
                        Text(f)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
            }
        }
    }
}

// MARK: - File results

struct FileListCard: View {
    let items: [FileCardData]

    var body: some View {
        CardChrome(onOpen: nil) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Files")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ForEach(Array(items.prefix(6).enumerated()), id: \.offset) { _, file in
                    Button {
                        CardDeepLink.revealInFinder(path: file.path)
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: symbol(for: file))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.name)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(file.path)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if items.count > 6 {
                    Text("+\(items.count - 6) more")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func symbol(for f: FileCardData) -> String {
        switch f.kindHint.lowercased() {
        case "folder", "directory": return "folder"
        case "image", "jpg", "jpeg", "png", "gif", "heic": return "photo"
        case "pdf": return "doc.richtext"
        case "video", "mov", "mp4", "m4v": return "film"
        case "audio", "mp3", "wav", "m4a", "aac": return "waveform"
        case "code", "swift", "py", "js", "ts", "rs", "go": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}

// MARK: - Web results

struct WebResultsCard: View {
    let items: [WebResultCardData]

    var body: some View {
        CardChrome(onOpen: nil) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Search results")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ForEach(Array(items.prefix(4).enumerated()), id: \.offset) { _, item in
                    Button {
                        CardDeepLink.open(item.url)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let snippet = item.snippet, !snippet.isEmpty {
                                Text(snippet)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Text(item.url)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if items.count > 4 {
                    Text("+\(items.count - 4) more")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Wikipedia

struct WikipediaCard: View {
    let data: WikipediaCardData

    var body: some View {
        CardChrome(
            onOpen: data.url.map { url in { CardDeepLink.open(url) } },
            openLabel: "Read on Wikipedia"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Wikipedia")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(data.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(data.summary)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(5)
            }
        }
    }
}
