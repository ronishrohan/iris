import Foundation
import AppKit

struct OpenAppTool: Tool {
    let name = "open_app"
    let displayName = "Open application"
    let description = "Launch a macOS application by name (e.g. \"Safari\", \"Slack\")."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "app_name": ["type": "string", "description": "Application name as it appears in /Applications."]
        ]),
        "required": AnyCodable(["app_name"])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        guard let appName = arguments["app_name"] as? String else {
            throw ToolError.invalidArguments
        }
        return try await MainActor.run {
            let ws = NSWorkspace.shared
            if let url = ws.urlForApplication(withBundleIdentifier: appName)
                ?? ws.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/\(appName).app")) {
                let cfg = NSWorkspace.OpenConfiguration()
                ws.openApplication(at: url, configuration: cfg)
                return "Opened \(appName)."
            }
            throw ToolError.notFound("Application '\(appName)' not found.")
        }
    }
}

enum ToolError: LocalizedError {
    case invalidArguments
    case notFound(String)
    case notImplemented
    case denied(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments: "Invalid arguments."
        case .notFound(let s): s
        case .notImplemented: "Not implemented yet."
        case .denied(let s): s
        }
    }
}
