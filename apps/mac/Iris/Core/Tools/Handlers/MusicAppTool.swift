import Foundation

struct MusicAppTool: Tool {
    let name = "apple_music_control"
    let displayName = "Apple Music control"
    let description = "Control the macOS Music app: play, pause, next, previous."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "action": ["type": "string", "enum": ["play","pause","next","previous"]]
        ]),
        "required": AnyCodable(["action"])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        guard let action = arguments["action"] as? String else { throw ToolError.invalidArguments }
        let verb: String
        switch action {
        case "play": verb = "play"
        case "pause": verb = "pause"
        case "next": verb = "next track"
        case "previous": verb = "previous track"
        default: throw ToolError.invalidArguments
        }
        try await AppleScript.run("tell application \"Music\" to \(verb)")
        return "Music: \(action)."
    }
}
