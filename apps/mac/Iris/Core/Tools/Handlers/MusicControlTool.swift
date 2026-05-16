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
        try await runRich(argumentsJSON: argumentsJSON).modelText
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
        let args = try parseArguments(argumentsJSON)
        guard let action = args["action"] as? String else { throw ToolError.invalidArguments }

        func wrap(_ text: String, actionLabel: String) -> ToolRunResult {
            // Try to pull "Title — Artist" from the script output. Falls
            // back to nothing.
            var title: String? = nil
            var artist: String? = nil
            if text.contains(" — ") {
                let pieces = text.split(separator: "—", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if pieces.count == 2 {
                    title = pieces[0]
                    artist = pieces[1]
                }
            }
            let card = MusicCardData(title: title, artist: artist, action: actionLabel)
            return .rich(text: text, ui: ToolUIResult(kind: .music(card)))
        }

        switch action {
        case "play":
            return wrap(try runScript("tell application \"Music\" to play", success: "Playing."), actionLabel: "Playing")
        case "pause":
            return wrap(try runScript("tell application \"Music\" to pause", success: "Paused."), actionLabel: "Paused")
        case "play_pause":
            return wrap(try runScript("tell application \"Music\" to playpause", success: "Toggled play."), actionLabel: "Toggled")
        case "next":
            return wrap(try runScript("tell application \"Music\" to next track", success: "Next track."), actionLabel: "Next")
        case "previous":
            return wrap(try runScript("tell application \"Music\" to previous track", success: "Previous track."), actionLabel: "Previous")
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
            let out = try runAndReturn(src)
            return wrap(out, actionLabel: "Now playing")
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
            let out = try runAndReturn(src)
            return wrap(out, actionLabel: "Playing")
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
