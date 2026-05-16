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
        // NSMetadataQuery throws on a single-subpredicate NSCompoundPredicate,
        // so unwrap when we only have one clause.
        let predicate: NSPredicate = clauses.count == 1
            ? clauses[0]
            : NSCompoundPredicate(andPredicateWithSubpredicates: clauses)

        let paths: [String] = await runSpotlightQuery(predicate: predicate, hardTimeout: 4.0)
        if paths.isEmpty { return "No files matched \"\(q)\"." }
        return paths.map { "• \($0)" }.joined(separator: "\n")
    }

    /// Wraps NSMetadataQuery so it always returns within `hardTimeout`
    /// and tears its observer + query down exactly once. Honours
    /// Task.cancellation: if the parent Task is cancelled the query is
    /// stopped immediately.
    private func runSpotlightQuery(predicate: NSPredicate,
                                   hardTimeout: TimeInterval) async -> [String] {
        await withCheckedContinuation { cont in
            let box = QueryBox()
            box.query = NSMetadataQuery()
            guard let q = box.query else {
                cont.resume(returning: [])
                return
            }
            q.predicate = predicate
            q.searchScopes = [NSMetadataQueryUserHomeScope]
            q.sortDescriptors = [
                NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)
            ]

            // Single-shot resume: prevents double resume from the
            // observer-then-timeout race or vice-versa.
            let resumeOnce: ([String]) -> Void = { [box] paths in
                let willResume: Bool = {
                    if box.finished { return false }
                    box.finished = true
                    return true
                }()
                guard willResume else { return }
                if let obs = box.observer {
                    NotificationCenter.default.removeObserver(obs)
                    box.observer = nil
                }
                if let q = box.query {
                    q.disableUpdates()
                    q.stop()
                    box.query = nil
                }
                cont.resume(returning: paths)
            }

            box.observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: q, queue: .main
            ) { [weak box] _ in
                guard let box, let q = box.query else { return }
                let items = (q.results as? [NSMetadataItem]) ?? []
                let out: [String] = items.prefix(15).compactMap { item in
                    item.value(forAttribute: NSMetadataItemPathKey) as? String
                }
                resumeOnce(out)
            }

            DispatchQueue.main.async {
                _ = q.start()
            }

            // Hard timeout: short, so a stuck Spotlight can't hang the
            // turn (the user can also Esc to interrupt at the
            // orchestrator level, but the tool itself stays bounded).
            DispatchQueue.main.asyncAfter(deadline: .now() + hardTimeout) {
                resumeOnce([])
            }
        }
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
    var observer: NSObjectProtocol?
    var finished = false
}
