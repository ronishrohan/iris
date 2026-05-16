import Foundation

protocol Tool: Sendable {
    var name: String { get }
    var displayName: String { get }
    var description: String { get }
    var parameters: [String: AnyCodable] { get }
    func run(argumentsJSON: String) async throws -> String

    /// Opt-in richer variant. Tools that have a structured payload for
    /// a native-feeling card (reminders, timers, calendar, etc.)
    /// override this and return `.rich(text:ui:)`. The default
    /// implementation just wraps the plain-text `run` output, so
    /// existing tools keep working unchanged.
    func runRich(argumentsJSON: String) async throws -> ToolRunResult
}

extension Tool {
    var spec: ToolSpec {
        ToolSpec(function: .init(name: name, description: description, parameters: parameters))
    }

    func parseArguments(_ json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    func runRich(argumentsJSON: String) async throws -> ToolRunResult {
        let text = try await run(argumentsJSON: argumentsJSON)
        return .text(text)
    }
}
