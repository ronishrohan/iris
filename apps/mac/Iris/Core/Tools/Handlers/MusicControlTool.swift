import Foundation
import AppKit

struct MusicControlTool: Tool {
    let name = "music_control"
    let displayName = "Music control"
    let description = "Control Apple Music: play, pause, next, previous, what's playing, play a specific track or playlist."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "action": [
                "type": "string",
                "enum": ["play", "pause", "play_pause", "next", "previous", "now_playing", "play_track"],
                "description": "What to do."
            ],
            "query": [
                "type": "string",
                "description": "Track / album / artist / playlist name for play_track."
            ]
        ]),
        "required": AnyCodable(["action"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let action = args["action"] as? String else { throw ToolError.invalidArguments }

        switch action {
        case "play":         return try runScript("tell application \"Music\" to play", success: "Playing.")
        case "pause":        return try runScript("tell application \"Music\" to pause", success: "Paused.")
        case "play_pause":   return try runScript("tell application \"Music\" to playpause", success: "Toggled play.")
        case "next":         return try runScript("tell application \"Music\" to next track", success: "Next track.")
        case "previous":     return try runScript("tell application \"Music\" to previous track", success: "Previous track.")
        case "now_playing":
            let src = """
            if application "Music" is running then
                tell application "Music"
                    if player state is playing or player state is paused then
                        return (name of current track) & " — " & (artist of current track)
                    end if
                end tell
            end if
            return "Nothing playing."
            """
            return try runAndReturn(src)
        case "play_track":
            guard let q = args["query"] as? String, !q.isEmpty else { throw ToolError.invalidArguments }
            let escaped = q.replacingOccurrences(of: "\"", with: "\\\"")
            let src = """
            tell application "Music"
                activate
                set theTracks to (every track of library playlist 1 whose name contains "\(escaped)" or artist contains "\(escaped)" or album contains "\(escaped)")
                if (count of theTracks) > 0 then
                    play (item 1 of theTracks)
                    return "Playing " & (name of item 1 of theTracks) & " — " & (artist of item 1 of theTracks)
                else
                    return "No match for \(escaped) in your library."
                end if
            end tell
            """
            return try runAndReturn(src)
        default:
            throw ToolError.invalidArguments
        }
    }

    private func runScript(_ src: String, success: String) throws -> String {
        var error: NSDictionary?
        _ = NSAppleScript(source: src)?.executeAndReturnError(&error)
        if let error { throw ToolError.denied("AppleScript: \(error["NSAppleScriptErrorMessage"] ?? "unknown")") }
        return success
    }

    private func runAndReturn(_ src: String) throws -> String {
        var error: NSDictionary?
        let out = NSAppleScript(source: src)?.executeAndReturnError(&error)
        if let error { throw ToolError.denied("AppleScript: \(error["NSAppleScriptErrorMessage"] ?? "unknown")") }
        return out?.stringValue ?? ""
    }
}
