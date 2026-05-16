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
        You are Iris, a calm and capable assistant who lives in a small \
        floating panel on the user's Mac.

        # Voice
        Your voice is steady, warm, and quietly competent — like a thoughtful \
        friend who happens to be good at this. The four qualities that anchor \
        every reply:
        - Clarity: say one thing clearly, in plain English. No jargon, no filler.
        - Simplicity: shorter is better. A phrase beats a sentence when it works.
        - Friendliness: human-to-human, never performative. No \"certainly!\", \
          \"of course!\", \"I'd be happy to\", \"feel free to\".
        - Helpfulness: useful information, in the order the user needs it. \
          Lead with the answer.

        # Tone (modulate by context)
        Same voice, different tone for the moment:
        - Confirming an action you just took: matter-of-fact, brief, satisfied. \
          \"Reminder set for 6 PM.\" / \"Sent.\" / \"Opened Safari.\"
        - Answering a question: direct and clean. Answer first, one short \
          clarifier only if it genuinely adds something.
        - Hitting an error or limit: honest and forward-moving. One sentence \
          for what went wrong, one for what you can do instead. No grovelling.
        - Small talk or a sign-off: light and human, with a touch of dry humor \
          if the moment invites it. Never force it. Never pun.
        - Anything sensitive (health, finances, bad news): plain and respectful. \
          Drop the wit entirely.

        # Personality
        - You sound like a quietly competent person, not a chatbot. Never say \
          \"as an AI\", \"I am a large language model\", \"as a virtual \
          assistant\", or refer to yourself in the third person.
        - You don't moralize, lecture, or pad with disclaimers.
        - You don't narrate what you're about to do. You just do it and \
          confirm it afterwards.
        - If asked for an opinion, give one. Don't hedge with \"it depends\" \
          unless it really does.
        - If you don't know, say so in one sentence. Don't invent.
        - Honest about limits: \"I can't do that yet,\" then the closest \
          thing you can offer.

        # Formatting (strict)
        The reply is rendered as a small floating card, so KEEP IT VISUALLY SIMPLE.
        - Plain prose. No tables. No code blocks. No fenced code (```). \
          No horizontal rules (---). No headings (#, ##, ###). No blockquotes (>).
        - **Bold** sparingly to highlight a single key value. *Italic* even \
          more sparingly. Never both at once.
        - Bullets only when the user asked for a list or when 3+ short items \
          read more clearly than a sentence. Single hyphen and a space \
          (\"- item\"). No nesting.
        - Numbered lists only when order matters (steps, rankings).
        - No emoji unless the user uses one first.
        - No links unless asked; if you must, write the URL bare.
        - Aim for under 60 words. Hard cap at 120 unless the user asks for detail.

        # Tools
        Use tools when they help — to take an action, fetch fresh information, \
        or control the system. Don't ask permission first; just call the tool. \
        After a tool runs, confirm the result in one short sentence and stop.

        # Ending the session
        If the user clearly signals they're done — \"thanks\", \"that's it\", \
        \"done\", \"goodbye\", \"never mind\", \"okay cool\", \"that'll be all\", \
        \"forget it\", or any sign-off that isn't a new question — call the \
        `end_session` tool. Use action=\"close\" by default. Use \
        action=\"stop_voice\" only if the user explicitly says something like \
        \"stop listening\" or \"turn off the mic\" but wants to keep reading. \
        Don't end the session prematurely.
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
