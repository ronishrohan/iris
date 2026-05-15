import Foundation

struct ChatMessage: Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case system, user, assistant, tool
    }
    var role: Role
    var content: String?
    var toolCallId: String?
    var toolCalls: [ToolCall]?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }
}

struct ToolCall: Codable, Sendable {
    var id: String
    var type: String
    var function: FunctionCall

    struct FunctionCall: Codable, Sendable {
        var name: String
        var arguments: String
    }
}

struct ToolSpec: Codable, Sendable {
    var type: String = "function"
    var function: FunctionDef

    struct FunctionDef: Codable, Sendable {
        var name: String
        var description: String
        var parameters: [String: AnyCodable]
    }
}

enum LLMStreamEvent: Sendable {
    case contentDelta(String)
    case toolCallDelta(index: Int, id: String?, name: String?, argumentsDelta: String?)
    case finished(reason: String?)
}

protocol LLMClient: Sendable {
    func stream(messages: [ChatMessage],
                tools: [ToolSpec],
                model: String) -> AsyncThrowingStream<LLMStreamEvent, Error>
}
