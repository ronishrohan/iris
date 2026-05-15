import Foundation

protocol Tool: Sendable {
    var name: String { get }
    var displayName: String { get }
    var description: String { get }
    var parameters: [String: AnyCodable] { get }
    func run(arguments: [String: Any]) async throws -> String
}

extension Tool {
    var spec: ToolSpec {
        ToolSpec(function: .init(name: name, description: description, parameters: parameters))
    }
}
