import Foundation
import AppKit

struct QuitAppTool: Tool {
    let name = "quit_app"
    let displayName = "Quit application"
    let description = "Quit a running macOS application by name or bundle id."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "app_name": ["type": "string", "description": "App display name (e.g. Safari) or bundle id."]
        ]),
        "required": AnyCodable(["app_name"])
    ]

    func run(argumentsJSON: String) async throws -> String {
        let args = try parseArguments(argumentsJSON)
        guard let name = args["app_name"] as? String, !name.isEmpty else {
            throw ToolError.invalidArguments
        }

        return try await MainActor.run {
            let running = NSWorkspace.shared.runningApplications
            // Try bundle id first
            if let app = running.first(where: { $0.bundleIdentifier == name }) {
                app.terminate()
                return "Quit \(app.localizedName ?? name)."
            }
            // Then localized name (case-insensitive)
            let lower = name.lowercased()
            if let app = running.first(where: {
                ($0.localizedName?.lowercased() == lower) ||
                (($0.localizedName ?? "") + ".app").lowercased() == lower
            }) {
                app.terminate()
                return "Quit \(app.localizedName ?? name)."
            }
            throw ToolError.notFound("'\(name)' isn't running.")
        }
    }
}
