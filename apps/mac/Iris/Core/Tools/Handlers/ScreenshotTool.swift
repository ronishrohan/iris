import Foundation
import AppKit

struct ScreenshotTool: Tool {
    let name = "screenshot"
    let displayName = "Screenshot"
    let description = "Take a screenshot of the entire screen and save it to ~/Desktop."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([:] as [String: Any])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let path = desktop.appendingPathComponent("iris-\(stamp).png").path
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", path]
        try task.run()
        task.waitUntilExit()
        return "Saved screenshot to \(path)."
    }
}
