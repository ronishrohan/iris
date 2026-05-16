import Foundation

@MainActor
final class ConversationOrchestrator {
    private let appState: AppState
    private let registry: ToolRegistry

    init(appState: AppState) {
        self.appState = appState
        self.registry = ToolRegistry(settings: appState.settings)
    }

    func turn(userText: String) async {
        appState.latestResponse = ""
        appState.phase = .thinking

        let apiKey = appState.settings.deepseekApiKey
        guard !apiKey.isEmpty else {
            appState.phase = .error("Add your DeepSeek key in Settings → Provider.")
            return
        }

        let client = DeepSeekClient(apiKey: apiKey)
        let tools = registry.enabledTools().map(\.spec)
        let model = appState.settings.defaultModel

        var messages: [ChatMessage] = [
            ChatMessage(role: .system,
                        content: "You are Iris, a concise assistant on macOS. Use tools when they help. Keep replies short and clear."),
            ChatMessage(role: .user, content: userText)
        ]

        do {
            try await runLoop(client: client, messages: &messages, tools: tools, model: model)
        } catch {
            appState.phase = .error(error.localizedDescription)
        }
    }

    private func runLoop(client: LLMClient,
                         messages: inout [ChatMessage],
                         tools: [ToolSpec],
                         model: String) async throws {
        var assistantText = ""
        var pendingToolCalls: [Int: PendingToolCall] = [:]

        for try await event in client.stream(messages: messages, tools: tools, model: model) {
            switch event {
            case .contentDelta(let s):
                assistantText += s
                appState.latestResponse = assistantText
            case .toolCallDelta(let idx, let id, let name, let argsDelta):
                var p = pendingToolCalls[idx] ?? PendingToolCall()
                if let id { p.id = id }
                if let name { p.name = name }
                if let d = argsDelta { p.arguments += d }
                pendingToolCalls[idx] = p
            case .finished:
                break
            }
        }

        if !pendingToolCalls.isEmpty {
            let toolCalls = pendingToolCalls
                .sorted { $0.key < $1.key }
                .map { (_, p) in
                    ToolCall(id: p.id,
                             type: "function",
                             function: .init(name: p.name, arguments: p.arguments))
                }
            messages.append(ChatMessage(role: .assistant,
                                        content: assistantText.isEmpty ? nil : assistantText,
                                        toolCallId: nil,
                                        toolCalls: toolCalls))

            for call in toolCalls {
                appState.phase = .toolCalling(name: call.function.name)
                let result: String
                do {
                    if let tool = registry.find(call.function.name) {
                        result = try await tool.run(argumentsJSON: call.function.arguments)
                    } else {
                        result = "Unknown tool: \(call.function.name)"
                    }
                } catch {
                    result = "Error: \(error.localizedDescription)"
                }
                messages.append(ChatMessage(role: .tool,
                                            content: result,
                                            toolCallId: call.id,
                                            toolCalls: nil))
            }

            appState.phase = .thinking
            try await runLoop(client: client, messages: &messages, tools: tools, model: model)
            return
        }

        appState.phase = .done
    }

    private struct PendingToolCall {
        var id: String = ""
        var name: String = ""
        var arguments: String = ""
    }
}
