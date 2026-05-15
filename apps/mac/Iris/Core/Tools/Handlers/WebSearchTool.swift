import Foundation

struct WebSearchTool: Tool {
    let name = "web_search"
    let displayName = "Web search"
    let description = "Search the web and return top result snippets."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "query": ["type": "string", "description": "Search query"]
        ]),
        "required": AnyCodable(["query"])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        // Placeholder: DeepSeek V4 has built-in web access in many configs;
        // we'll route through their search tool or a separate provider later.
        throw ToolError.notImplemented
    }
}
