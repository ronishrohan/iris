import Foundation
import AppKit

struct OpenURLTool: Tool {
    let name = "open_url"
    let displayName = "Open URL"
    let description = "Open a URL in the user's default browser."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "url": ["type": "string", "description": "Full URL including scheme (https://...)"]
        ]),
        "required": AnyCodable(["url"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard var raw = args["url"] as? String, !raw.isEmpty else { throw ToolError.invalidArguments }
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "https://" + raw
        }
        guard let url = URL(string: raw) else { throw ToolError.invalidArguments }
        let host = url.host ?? raw
        return await MainActor.run {
            NSWorkspace.shared.open(url)
            return "Opened \(host)."
        }
    }
}
