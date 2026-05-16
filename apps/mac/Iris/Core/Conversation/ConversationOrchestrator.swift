import Foundation

@MainActor
final class ConversationOrchestrator {
    private let appState: AppState
    private let registry: ToolRegistry

    /// Persistent message history for the current open-session. Reset
    /// whenever the panel closes (see AppState.finishClose).
    private var sessionMessages: [ChatMessage] = []
    private let systemPrompt = ChatMessage(
        role: .system,
        content: """
        You are Iris, a concise assistant on macOS. Use tools when they help. \
        Keep replies short and clear. The user is talking to you through a \
        small floating panel, so favor brevity over verbosity.

        Ending the session: if the user clearly signals they're done — \
        \"thanks\", \"that's it\", \"done\", \"goodbye\", \"never mind\", \
        \"okay cool\", \"that'll be all\", \"forget it\", or any sign-off that \
        isn't a new question — call the `end_session` tool. \
        Use action=\"close\" by default. Use action=\"stop_voice\" only if the \
        user explicitly says something like \"stop listening\" or \"turn off the \
        mic\" but wants to keep reading. Don't end the session prematurely if \
        the user might still want a follow-up answer.
        """
    )

    init(appState: AppState) {
        self.appState = appState
        self.registry = ToolRegistry(settings: appState.settings)
    }

    /// Wipe the in-memory conversation. Called when the panel closes.
    func resetSession() {
        sessionMessages.removeAll(keepingCapacity: false)
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

        // Build messages: system + prior session turns + this user turn.
        var messages: [ChatMessage] = [systemPrompt]
        messages.append(contentsOf: sessionMessages)
        messages.append(ChatMessage(role: .user, content: userText))

        var ranAnyToolSuccessfully = false
        var anyToolFailed = false

        do {
            try await runLoop(client: client,
                              messages: &messages,
                              tools: tools,
                              model: model,
                              ranAnyToolSuccessfully: &ranAnyToolSuccessfully,
                              anyToolFailed: &anyToolFailed)
        } catch {
            appState.phase = .error(error.localizedDescription)
            return
        }

        // Persist the user turn and the assistant's final reply.
        sessionMessages.append(ChatMessage(role: .user, content: userText))
        if !appState.latestResponse.isEmpty {
            sessionMessages.append(ChatMessage(role: .assistant, content: appState.latestResponse))
        }

        // Push the finished response onto the stack so a follow-up
        // question doesn't wipe it visually.
        if !appState.latestResponse.isEmpty {
            appState.archiveCurrentResponse()
        }
        _ = ranAnyToolSuccessfully
        _ = anyToolFailed
    }

    private func runLoop(client: LLMClient,
                         messages: inout [ChatMessage],
                         tools: [ToolSpec],
                         model: String,
                         ranAnyToolSuccessfully: inout Bool,
                         anyToolFailed: inout Bool) async throws {
        var assistantText = ""
        var assistantReasoning = ""
        var pendingToolCalls: [Int: PendingToolCall] = [:]

        for try await event in client.stream(messages: messages, tools: tools, model: model) {
            switch event {
            case .contentDelta(let s):
                assistantText += s
                appState.latestResponse = assistantText
            case .reasoningDelta(let s):
                assistantReasoning += s
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
            messages.append(ChatMessage(
                role: .assistant,
                content: assistantText.isEmpty ? nil : assistantText,
                reasoningContent: assistantReasoning.isEmpty ? nil : assistantReasoning,
                toolCallId: nil,
                toolCalls: toolCalls
            ))

            for call in toolCalls {
                appState.phase = .toolCalling(name: call.function.name)
                var result: String
                do {
                    if let tool = registry.find(call.function.name) {
                        result = try await tool.run(argumentsJSON: call.function.arguments)
                        ranAnyToolSuccessfully = true
                    } else {
                        result = "Unknown tool: \(call.function.name)"
                        anyToolFailed = true
                    }
                } catch {
                    result = "Error: \(error.localizedDescription)"
                    anyToolFailed = true
                }
                // EndSessionTool emits a sentinel; act on it locally so
                // the panel actually closes or voice stops. We still
                // return a normal-looking tool result to the model so it
                // can wrap up cleanly.
                if result.hasPrefix(EndSessionTool.sentinelPrefix) {
                    let action = String(result.dropFirst(EndSessionTool.sentinelPrefix.count))
                    handleEndSession(action: action)
                    result = "Session ended."
                }
                messages.append(ChatMessage(role: .tool,
                                            content: result,
                                            toolCallId: call.id,
                                            toolCalls: nil))
            }

            appState.phase = .thinking
            try await runLoop(client: client,
                              messages: &messages,
                              tools: tools,
                              model: model,
                              ranAnyToolSuccessfully: &ranAnyToolSuccessfully,
                              anyToolFailed: &anyToolFailed)
            return
        }

        appState.phase = .done
    }

    private struct PendingToolCall {
        var id: String = ""
        var name: String = ""
        var arguments: String = ""
    }

    private func handleEndSession(action: String) {
        switch action {
        case "stop_voice":
            appState.stopVoiceOnly()
        default:
            // Brief delay so the user can see the assistant's closing
            // message before the panel disappears.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                appState.dismiss()
            }
        }
    }
}
