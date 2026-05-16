import Foundation
import AppKit

struct TakeNoteTool: Tool {
    let name = "take_note"
    let displayName = "Take note"
    let description = "Create a new note in Apple Notes."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "title": ["type": "string"],
            "body":  ["type": "string", "description": "Body text. Markdown will be rendered as plain text."]
        ]),
        "required": AnyCodable(["body"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        try await runRich(argumentsJSON: argumentsJSON).modelText
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
        let args = try parseArguments(argumentsJSON)
        let title = (args["title"] as? String) ?? "Iris note"
        let body  = (args["body"]  as? String) ?? ""
        let t = title.replacingOccurrences(of: "\"", with: "\\\"")
        let b = body.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "<br>")

        let src = """
        tell application "Notes"
            tell account 1
                make new note with properties {name:"\(t)", body:"\(t)<br><br>\(b)"}
            end tell
        end tell
        """
        var error: NSDictionary?
        _ = NSAppleScript(source: src)?.executeAndReturnError(&error)
        if let error { throw ToolError.denied("Notes: \(error["NSAppleScriptErrorMessage"] ?? "unknown")") }

        let preview = title.isEmpty ? body : "\(title)\n\(body)"
        let card = NoteCardData(preview: preview, folder: nil)
        return .rich(text: "Saved note: \(title).",
                     ui: ToolUIResult(kind: .note(card)))
    }
}
