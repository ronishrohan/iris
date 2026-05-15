import Foundation

struct SpotifyTool: Tool {
    let name = "spotify_control"
    let displayName = "Spotify control"
    let description = "Control Spotify: play, pause, next, previous, or play a track by name."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "action": ["type": "string", "enum": ["play","pause","next","previous","play_track"]],
            "query": ["type": "string", "description": "Track or artist when action is play_track."]
        ]),
        "required": AnyCodable(["action"])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        guard let action = arguments["action"] as? String else { throw ToolError.invalidArguments }
        let cmd: String
        switch action {
        case "play": cmd = "tell application \"Spotify\" to play"
        case "pause": cmd = "tell application \"Spotify\" to pause"
        case "next": cmd = "tell application \"Spotify\" to next track"
        case "previous": cmd = "tell application \"Spotify\" to previous track"
        case "play_track":
            guard let q = arguments["query"] as? String else { throw ToolError.invalidArguments }
            cmd = "tell application \"Spotify\" to play track \"\(q)\""
        default: throw ToolError.invalidArguments
        }
        try await AppleScript.run(cmd)
        return "Spotify: \(action)."
    }
}
