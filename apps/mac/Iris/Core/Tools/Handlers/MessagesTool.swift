import Foundation
import AppKit

struct SendIMessageTool: Tool {
    let name = "send_imessage"
    let displayName = "Send iMessage"
    let description = "Send an iMessage to a contact by phone number, email, or saved name."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "recipient": ["type": "string", "description": "Phone number, email, or contact name."],
            "message":   ["type": "string", "description": "Message body."]
        ]),
        "required": AnyCodable(["recipient", "message"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let recipient = args["recipient"] as? String, !recipient.isEmpty,
              let body = args["message"] as? String, !body.isEmpty else {
            throw ToolError.invalidArguments
        }
        let r = recipient.replacingOccurrences(of: "\"", with: "\\\"")
        let m = body.replacingOccurrences(of: "\"", with: "\\\"")
        let src = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(r)" of targetService
            send "\(m)" to targetBuddy
        end tell
        """
        var error: NSDictionary?
        _ = NSAppleScript(source: src)?.executeAndReturnError(&error)
        if let error {
            throw ToolError.denied("Messages: \(error["NSAppleScriptErrorMessage"] ?? "unknown")")
        }
        return "Sent to \(recipient)."
    }
}
