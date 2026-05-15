import Foundation

struct SystemControlTool: Tool {
    let name = "system_control"
    let displayName = "System volume & brightness"
    let description = "Set system volume (0-100) or display brightness (0-100)."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "kind": ["type": "string", "enum": ["volume","brightness"]],
            "value": ["type": "integer", "description": "0-100"]
        ]),
        "required": AnyCodable(["kind","value"])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        guard let kind = arguments["kind"] as? String,
              let value = arguments["value"] as? Int else { throw ToolError.invalidArguments }
        let clamped = max(0, min(100, value))
        switch kind {
        case "volume":
            try await AppleScript.run("set volume output volume \(clamped)")
            return "Volume set to \(clamped)%."
        case "brightness":
            // Brightness has no AppleScript; use `brightness` CLI if available,
            // else fall back to a no-op with helpful error.
            throw ToolError.notImplemented
        default: throw ToolError.invalidArguments
        }
    }
}
