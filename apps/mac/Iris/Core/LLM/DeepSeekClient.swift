import Foundation

final class DeepSeekClient: LLMClient {
    let baseURL: URL
    let apiKey: String

    init(apiKey: String, baseURL: URL = URL(string: "https://api.deepseek.com")!) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func stream(messages: [ChatMessage],
                tools: [ToolSpec],
                model: String) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = baseURL.appendingPathComponent("chat/completions")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    var body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": messages.map { msgToDict($0) }
                    ]
                    if !tools.isEmpty {
                        body["tools"] = try toolsArray(tools)
                        body["tool_choice"] = "auto"
                    }
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        // Read whatever the server sent back so we can show
                        // the real error reason instead of a generic 400.
                        var errBody = ""
                        for try await line in bytes.lines {
                            errBody += line
                            if errBody.count > 2000 { break }
                        }
                        let detail = errBody.trimmingCharacters(in: .whitespacesAndNewlines)
                        let msg = detail.isEmpty
                            ? "HTTP \(status) from DeepSeek"
                            : "HTTP \(status): \(detail)"
                        throw NSError(domain: "DeepSeek", code: status,
                                      userInfo: [NSLocalizedDescriptionKey: msg])
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" {
                            continuation.yield(.finished(reason: "stop"))
                            continuation.finish()
                            return
                        }
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let first = choices.first else { continue }
                        let delta = (first["delta"] as? [String: Any]) ?? [:]
                        if let content = delta["content"] as? String, !content.isEmpty {
                            continuation.yield(.contentDelta(content))
                        }
                        if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                            continuation.yield(.reasoningDelta(reasoning))
                        }
                        if let tcs = delta["tool_calls"] as? [[String: Any]] {
                            for tc in tcs {
                                let idx = tc["index"] as? Int ?? 0
                                let id = tc["id"] as? String
                                let function = tc["function"] as? [String: Any]
                                let name = function?["name"] as? String
                                let argsDelta = function?["arguments"] as? String
                                continuation.yield(.toolCallDelta(index: idx, id: id, name: name, argumentsDelta: argsDelta))
                            }
                        }
                        if let reason = first["finish_reason"] as? String {
                            continuation.yield(.finished(reason: reason))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func msgToDict(_ m: ChatMessage) -> [String: Any] {
        var d: [String: Any] = ["role": m.role.rawValue]
        if let c = m.content, !c.isEmpty {
            d["content"] = c
        } else if m.role == .tool {
            d["content"] = "(no output)"
        }
        // Thinking mode: DeepSeek requires the reasoning_content from the
        // previous turn to be passed back on the assistant message.
        if m.role == .assistant, let r = m.reasoningContent, !r.isEmpty {
            d["reasoning_content"] = r
        }
        if let id = m.toolCallId { d["tool_call_id"] = id }
        if let tcs = m.toolCalls, !tcs.isEmpty {
            d["tool_calls"] = tcs.map { tc -> [String: Any] in
                [
                    "id": tc.id,
                    "type": tc.type,
                    "function": [
                        "name": tc.function.name,
                        "arguments": tc.function.arguments.isEmpty ? "{}" : tc.function.arguments
                    ]
                ]
            }
        }
        return d
    }

    private func toolsArray(_ tools: [ToolSpec]) throws -> [[String: Any]] {
        let data = try JSONEncoder().encode(tools)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr
    }
}
