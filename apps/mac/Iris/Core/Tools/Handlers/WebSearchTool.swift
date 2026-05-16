import Foundation

struct WebSearchTool: Tool {
    let name = "web_search"
    let displayName = "Web search"
    let description = "Search the web and return concise snippets for the top results."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "query": ["type": "string", "description": "Search query"]
        ]),
        "required": AnyCodable(["query"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let arguments = try parseArguments(argumentsJSON)
        guard let query = arguments["query"] as? String, !query.isEmpty else {
            throw ToolError.invalidArguments
        }

        // DuckDuckGo Instant Answer API — no key required.
        var comps = URLComponents(string: "https://api.duckduckgo.com/")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_html", value: "1"),
            URLQueryItem(name: "skip_disambig", value: "1")
        ]
        guard let url = comps.url else { throw ToolError.invalidArguments }

        var req = URLRequest(url: url)
        req.setValue("Iris/0.1 (macOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ToolError.notFound("Search failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)).")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "No results."
        }

        var parts: [String] = []
        if let abstract = json["AbstractText"] as? String, !abstract.isEmpty {
            parts.append(abstract)
            if let src = json["AbstractURL"] as? String, !src.isEmpty {
                parts.append("Source: \(src)")
            }
        }
        if let answer = json["Answer"] as? String, !answer.isEmpty {
            parts.append(answer)
        }
        if let topics = json["RelatedTopics"] as? [[String: Any]] {
            let snippets: [String] = topics.prefix(5).compactMap { t in
                if let text = t["Text"] as? String, !text.isEmpty { return "• \(text)" }
                return nil
            }
            if !snippets.isEmpty { parts.append(contentsOf: snippets) }
        }
        if parts.isEmpty {
            return "No direct answer for \"\(query)\". Try rephrasing."
        }
        return parts.joined(separator: "\n")
    }
}
