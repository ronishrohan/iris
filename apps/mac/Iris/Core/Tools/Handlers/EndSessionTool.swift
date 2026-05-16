import Foundation

/// Lets the LLM end the current session when the user signals they're
/// done ("thanks", "that's all", "goodbye", "okay done", etc.).
///
/// The tool itself just emits a sentinel string. The orchestrator
/// detects the sentinel and performs the actual UI side-effect on
/// `AppState` so we keep tool implementations Sendable and stateless.
struct EndSessionTool: Tool {
    let name = "end_session"
    let displayName = "End session"
    let description = """
    Use this when the user clearly signals the conversation is finished — \
    phrases like \"thanks, that's it\", \"done\", \"goodbye\", \"that'll be all\", \
    \"never mind\", \"okay cool, thanks\", or any sign-off where they aren't \
    asking another question. Set `action` to \"close\" to close the Iris panel \
    entirely, or \"stop_voice\" to just turn off voice listening but keep the \
    panel visible so the user can read the last response.
    """
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "action": [
                "type": "string",
                "enum": ["close", "stop_voice"],
                "description": "What to do — close the panel or just stop voice listening."
            ]
        ]),
        "required": AnyCodable(["action"])
    ]

    /// Sentinel prefix the orchestrator looks for. Any tool output that
    /// starts with this is treated as a control directive instead of a
    /// normal tool result.
    static let sentinelPrefix = "__IRIS_END_SESSION__:"

    func run(argumentsJSON: String) async throws -> String {
        let arguments = try parseArguments(argumentsJSON)
        let raw = (arguments["action"] as? String)?.lowercased() ?? "close"
        let action = (raw == "stop_voice") ? "stop_voice" : "close"
        return "\(Self.sentinelPrefix)\(action)"
    }
}
