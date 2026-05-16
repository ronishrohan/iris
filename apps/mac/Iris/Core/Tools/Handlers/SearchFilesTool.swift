import Foundation
import AppKit

struct SearchFilesTool: Tool {
    let name = "search_files"
    let displayName = "Search files"
    let description = "Search the user's files via Spotlight. Returns up to 15 paths."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "query": ["type": "string", "description": "Free-text query (e.g. 'taxes 2025 spreadsheet')."],
            "kind":  ["type": "string", "description": "Optional: 'pdf', 'image', 'document', 'spreadsheet', 'video', 'audio'."]
        ]),
        "required": AnyCodable(["query"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let q = args["query"] as? String, !q.isEmpty else { throw ToolError.invalidArguments }
        let kind = (args["kind"] as? String)?.lowercased()

        // Build a Spotlight query. Use NSPredicate's argument substitution
        // (the `%@` form) so quotes / wildcards / unicode in the query
        // can't break the string — that was the source of an earlier
        // "Syntax error in Metadata query string" crash.
        let wildcard = "*\(q)*"
        var clauses: [NSPredicate] = []
        clauses.append(NSPredicate(format: "(kMDItemFSName LIKE[c] %@) OR (kMDItemDisplayName LIKE[c] %@) OR (kMDItemTextContent LIKE[c] %@)",
                                   wildcard, wildcard, wildcard))
        if let kind {
            // `kMDItemContentTypeTree` is a multi-valued attribute, so
            // the right operator is membership rather than equality.
            let uti: String? = {
                switch kind {
                case "pdf":         return "com.adobe.pdf"
                case "image":       return "public.image"
                case "document":    return "public.content"
                case "spreadsheet": return "public.spreadsheet"
                case "video":       return "public.movie"
                case "audio":       return "public.audio"
                default: return nil
                }
            }()
            if let uti {
                clauses.append(NSPredicate(format: "%@ IN kMDItemContentTypeTree", uti))
            }
        }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: clauses)

        let paths: [String] = await withCheckedContinuation { cont in
            let box = QueryBox()
            box.query = NSMetadataQuery()
            let q = box.query!
            q.predicate = predicate
            q.searchScopes = [NSMetadataQueryUserHomeScope]
            q.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]

            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: q, queue: .main
            ) { [box] _ in
                guard let q = box.query else { return }
                q.disableUpdates()
                q.stop()
                let items = (q.results as? [NSMetadataItem]) ?? []
                let out: [String] = items.prefix(15).compactMap { item in
                    item.value(forAttribute: NSMetadataItemPathKey) as? String
                }
                if let observer { NotificationCenter.default.removeObserver(observer) }
                box.finished = true
                cont.resume(returning: out)
            }
            DispatchQueue.main.async { [box] in
                _ = box.query?.start()
            }
            // safety timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [box] in
                guard !box.finished, let q = box.query, q.isStarted else { return }
                q.stop()
                box.finished = true
                cont.resume(returning: [])
            }
        }
        if paths.isEmpty { return "No files matched \"\(q)\"." }
        return paths.map { "• \($0)" }.joined(separator: "\n")
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
        let text = try await run(argumentsJSON: argumentsJSON)
        // No-match path returns just the "No files…" string.
        if text.hasPrefix("No files matched") {
            return .text(text)
        }
        let lines = text.split(separator: "\n").map(String.init)
        let cards = lines.compactMap { line -> FileCardData? in
            var s = line
            if s.hasPrefix("• ") { s.removeFirst(2) }
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let url = URL(fileURLWithPath: trimmed)
            let ext = url.pathExtension.lowercased()
            return FileCardData(name: url.lastPathComponent, path: trimmed, kindHint: ext)
        }
        return .rich(text: text, ui: ToolUIResult(kind: .fileList(cards)))
    }
}

private final class QueryBox: @unchecked Sendable {
    var query: NSMetadataQuery?
    var finished = false
}
