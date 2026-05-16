import Foundation

struct WikipediaTool: Tool {
    let name = "wikipedia"
    let displayName = "Wikipedia"
    let description = "Look up a topic on Wikipedia and return a short summary."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "query": ["type": "string", "description": "Topic to look up (e.g. 'Alan Turing', 'Saturn')."]
        ]),
        "required": AnyCodable(["query"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let query = args["query"] as? String, !query.isEmpty else { throw ToolError.invalidArguments }

        let title = query
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(title)") else {
            throw ToolError.invalidArguments
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("Iris/0.1 (mac)", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw ToolError.notFound("Wikipedia request failed: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            throw ToolError.notFound("No HTTP response from Wikipedia.")
        }
        guard http.statusCode != 404 else {
            return "No Wikipedia article found for \"\(query)\"."
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ToolError.notFound("Wikipedia HTTP \(http.statusCode).")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.notFound("Couldn't parse Wikipedia response.")
        }
        let title2 = (json["title"] as? String) ?? query
        let extract = (json["extract"] as? String) ?? ""
        let pageURL = ((json["content_urls"] as? [String: Any])?["desktop"] as? [String: Any])?["page"] as? String

        if extract.isEmpty {
            return "Found \"\(title2)\" on Wikipedia, but no summary available."
        }
        var out = "**\(title2)**\n\n\(extract)"
        if let pageURL { out += "\n\nSource: \(pageURL)" }
        return out
    }
}
