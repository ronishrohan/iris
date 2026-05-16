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

        var predicates: [String] = []
        let escaped = q.replacingOccurrences(of: "\"", with: "\\\"")
        predicates.append("kMDItemFSName LIKE[c] \"*\(escaped)*\" || kMDItemTextContent LIKE[c] \"*\(escaped)*\"")
        if let kind {
            let typeUTI: String? = {
                switch kind {
                case "pdf":         return "com.adobe.pdf"
                case "image":       return "public.image"
                case "document":    return "public.composite-content"
                case "spreadsheet": return "com.microsoft.excel.xls"
                case "video":       return "public.movie"
                case "audio":       return "public.audio"
                default: return nil
                }
            }()
            if let uti = typeUTI { predicates.append("kMDItemContentTypeTree == \"\(uti)\"") }
        }

        let predicateStr = predicates.map { "(\($0))" }.joined(separator: " && ")
        guard let predicate = NSPredicate(fromMetadataQueryString: predicateStr) else {
            throw ToolError.invalidArguments
        }

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
}

private final class QueryBox: @unchecked Sendable {
    var query: NSMetadataQuery?
    var finished = false
}
