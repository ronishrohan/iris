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

    func run(argumentsJSON: String) async throws -> String {
        let arguments = try parseArguments(argumentsJSON)
        guard let appName = arguments["app_name"] as? String else {
            throw ToolError.invalidArguments
        }
        return try await MainActor.run {
            let ws = NSWorkspace.shared
            let fm = FileManager.default

            // Try direct bundle id (e.g. "com.apple.Terminal")
            if let url = ws.urlForApplication(withBundleIdentifier: appName) {
                openApp(url, ws: ws)
                return "Opened \(appName)."
            }

            // Try common app-bundle paths in standard application directories
            let baseName = appName.hasSuffix(".app") ? String(appName.dropLast(4)) : appName
            let searchDirs = [
                "/Applications",
                "/System/Applications",
                "/System/Applications/Utilities",
                "/Applications/Utilities",
                ("~/Applications" as NSString).expandingTildeInPath
            ]
            for dir in searchDirs {
                let path = "\(dir)/\(baseName).app"
                if fm.fileExists(atPath: path) {
                    openApp(URL(fileURLWithPath: path), ws: ws)
                    return "Opened \(baseName)."
                }
            }

            // Fall back to launching by display name using `open -a`. This
            // covers anything Launch Services knows about.
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", baseName]
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    return "Opened \(baseName)."
                }
            } catch { /* fall through to error below */ }

            throw ToolError.notFound("Application '\(appName)' not found.")
        }
    }

    private func openApp(_ url: URL, ws: NSWorkspace) {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        ws.openApplication(at: url, configuration: cfg)
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
