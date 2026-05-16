import Foundation
import AppKit

struct SendEmailTool: Tool {
    let name = "send_email"
    let displayName = "Compose email"
    let description = "Open a pre-filled draft email in the user's default mail client. Does not auto-send."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "to":      ["type": "string", "description": "Recipient email address."],
            "subject": ["type": "string"],
            "body":    ["type": "string"]
        ]),
        "required": AnyCodable(["to"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let to = args["to"] as? String, !to.isEmpty else { throw ToolError.invalidArguments }
        let subject = (args["subject"] as? String) ?? ""
        let body    = (args["body"]    as? String) ?? ""

        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = to
        var items: [URLQueryItem] = []
        if !subject.isEmpty { items.append(URLQueryItem(name: "subject", value: subject)) }
        if !body.isEmpty    { items.append(URLQueryItem(name: "body",    value: body))    }
        if !items.isEmpty   { comps.queryItems = items }

        guard let url = comps.url else { throw ToolError.invalidArguments }
        return await MainActor.run {
            NSWorkspace.shared.open(url)
            return "Opened a draft to \(to)."
        }
    }
}
