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

        // DuckDuckGo Instant Answer API — no key required. Note: this
        // endpoint is sparse and only returns rich results for
        // Wikipedia-style facts. For richer search we'll plug in a real
        // engine later.
        var comps = URLComponents(string: "https://api.duckduckgo.com/")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_html", value: "1"),
            URLQueryItem(name: "skip_disambig", value: "1")
        ]
        guard let url = comps.url else { throw ToolError.invalidArguments }

        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("Iris/0.1 (macOS)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw ToolError.notFound("Web search network error: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw ToolError.notFound("Web search failed: no HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ToolError.notFound("Web search failed (HTTP \(http.statusCode)).")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.notFound("Web search returned an unreadable response.")
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
        if let definition = json["Definition"] as? String, !definition.isEmpty {
            parts.append(definition)
            if let src = json["DefinitionURL"] as? String, !src.isEmpty {
                parts.append("Source: \(src)")
            }
        }
        if let topics = json["RelatedTopics"] as? [[String: Any]] {
            let snippets: [String] = topics.prefix(5).compactMap { t in
                if let text = t["Text"] as? String, !text.isEmpty {
                    if let result = t["FirstURL"] as? String, !result.isEmpty {
                        return "• \(text) — \(result)"
                    }
                    return "• \(text)"
                }
                return nil
            }
            if !snippets.isEmpty { parts.append(contentsOf: snippets) }
        }
        if parts.isEmpty {
            // Surface this back to the model as a no-results note rather
            // than throwing. The model can then explain to the user.
            return "No direct answer was found for \"\(query)\" on DuckDuckGo's instant-answer API. Tell the user that the current web-search backend only handles Wikipedia-style facts and richer search isn't wired up yet."
        }
        return parts.joined(separator: "\n")
    }
}
