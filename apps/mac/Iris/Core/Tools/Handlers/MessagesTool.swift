import Foundation

struct MessagesTool: Tool {
    let name = "send_imessage"
    let displayName = "Send iMessage"
    let description = "Send an iMessage to a contact. Requires user confirmation on first use."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "recipient": ["type": "string", "description": "Phone number, email, or contact name."],
            "body": ["type": "string"]
        ]),
        "required": AnyCodable(["recipient", "body"])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        guard let recipient = arguments["recipient"] as? String,
              let body = arguments["body"] as? String else { throw ToolError.invalidArguments }
        let script = """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "\(recipient)" of targetService
            send "\(body.replacingOccurrences(of: "\"", with: "\\\""))" to targetBuddy
        end tell
        """
        try await AppleScript.run(script)
        return "Sent iMessage to \(recipient)."
    }
}

enum AppleScript {
    static func run(_ source: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    _ = script.executeAndReturnError(&error)
                }
                if let error {
                    cont.resume(throwing: NSError(
                        domain: "AppleScript", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "\(error)"]))
                } else {
                    cont.resume()
                }
            }
        }
    }
}
