import Foundation

protocol Tool: Sendable {
    var name: String { get }
    var displayName: String { get }
    var description: String { get }
    var parameters: [String: AnyCodable] { get }
    func run(argumentsJSON: String) async throws -> String
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
}
