import Foundation
import AppKit

struct ShellTool: Tool {
    let name = "run_shell"
    let displayName = "Run shell command (with confirmation)"
    let description = "Run a shell command. Always asks user confirmation. Use sparingly."
    let parameters: [String: AnyCodable] = [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "command": ["type": "string"]
        ]),
        "required": AnyCodable(["command"])
    ]

    func run(arguments: [String: Any]) async throws -> String {
        guard let cmd = arguments["command"] as? String else { throw ToolError.invalidArguments }

        let approved = await MainActor.run { () -> Bool in
            let alert = NSAlert()
            alert.messageText = "Iris wants to run a shell command"
            alert.informativeText = cmd
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Deny")
            return alert.runModal() == .alertFirstButtonReturn
        }
        guard approved else { throw ToolError.denied("User denied shell execution.") }

        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-lc", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
