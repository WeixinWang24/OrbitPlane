import Foundation

final class CodexProvider: AgentProvider, @unchecked Sendable {
    private static let endpoint = URL(string: "https://chatgpt.com/backend-api/codex/responses")!

    let authManager: CodexAuthManager
    let session: URLSession
    var model: String

    var backendName: String { "openai-codex" }

    init(model: String = "codex",
         authManager: CodexAuthManager = CodexAuthManager(),
         session: URLSession = .shared) {
        self.model = model
        self.authManager = authManager
        self.session = session
    }

    func plan(
        from request: TurnRequest,
        onPartialText: (@Sendable (String) -> Void)? = nil
    ) async -> ProviderPlan {
        let credential: CodexCredential
        do {
            var loaded = try authManager.loadCredential()
            if loaded.isExpired {
                loaded = try await authManager.refresh(loaded)
                try authManager.saveCredential(loaded)
            }
            credential = loaded
        } catch {
            return errorPlan("Auth failed: \(error.localizedDescription)", errorType: "auth_failure")
        }

        guard !credential.accessToken.isEmpty else {
            return errorPlan("Access token is empty", errorType: "auth_failure")
        }

        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let payload = buildPayload(from: request)
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return errorPlan("Failed to encode request: \(error.localizedDescription)", errorType: "encode_failure")
        }

        do {
            let (bytes, response) = try await session.bytes(for: urlRequest)

            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                var body = ""
                for try await line in bytes.lines { body += line }
                return errorPlan("HTTP \(httpResponse.statusCode): \(body)", errorType: "http_error")
            }

            return try await parseSSEStream(bytes, onPartialText: onPartialText)
        } catch let error as CodexSSEError {
            return errorPlan(error.localizedDescription, errorType: "sse_error")
        } catch {
            return errorPlan("Connection failed: \(error.localizedDescription)", errorType: "connection_failure")
        }
    }

    // MARK: - Payload

    private func buildPayload(from request: TurnRequest) -> [String: Any] {
        var input: [[String: Any]] = []

        if let system = request.system {
            input.append(["role": "system", "content": system])
        }

        for msg in request.messages {
            if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                for tc in toolCalls {
                    input.append([
                        "type": "function_call",
                        "call_id": tc.id,
                        "name": tc.functionName,
                        "arguments": jsonValueToString(tc.arguments)
                    ])
                }
                continue
            }

            if msg.role == "tool", let callId = msg.toolCallID {
                input.append([
                    "type": "function_call_output",
                    "call_id": callId,
                    "output": msg.content ?? ""
                ])
                continue
            }

            input.append([
                "role": msg.role,
                "content": msg.content ?? ""
            ])
        }

        var payload: [String: Any] = [
            "model": model,
            "store": false,
            "stream": true,
            "input": input,
            "instructions": request.system ?? "",
            "text": ["verbosity": "medium"],
        ]

        if let tools = request.toolDefinitions, !tools.isEmpty {
            payload["tools"] = tools.map { tool -> [String: Any] in
                [
                    "type": "function",
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": jsonValueToNative(tool.parameters),
                ]
            }
        }

        return payload
    }

    // MARK: - SSE Parsing

    private func parseSSEStream(
        _ bytes: URLSession.AsyncBytes,
        onPartialText: (@Sendable (String) -> Void)?
    ) async throws -> ProviderPlan {
        var accumulatedText = ""
        var toolRequests: [ToolRequest] = []
        var metadata: [String: JSONValue] = [:]
        var resolvedModel = model

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))

            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = event["type"] as? String else {
                continue
            }

            switch type {
            case "response.output_text.delta":
                if let delta = event["delta"] as? String {
                    accumulatedText += delta
                    onPartialText?(delta)
                }

            case "response.output_text.done":
                if let text = event["text"] as? String {
                    accumulatedText = text
                }

            case "response.output_item.done":
                if let item = event["item"] as? [String: Any],
                   let itemType = item["type"] as? String,
                   itemType == "function_call" {
                    let callID = item["call_id"] as? String ?? UUID().uuidString
                    let name = item["name"] as? String ?? ""
                    let args = parseArguments(item["arguments"] as? String)
                    toolRequests.append(ToolRequest(
                        toolCallID: callID,
                        toolName: name,
                        arguments: args
                    ))
                }

            case "response.completed", "response.done":
                if let response = event["response"] as? [String: Any] {
                    if let m = response["model"] as? String { resolvedModel = m }
                    if let usage = response["usage"] as? [String: Any] {
                        if let input = usage["input_tokens"] as? Int {
                            metadata["prompt_tokens"] = .number(Double(input))
                        }
                        if let output = usage["output_tokens"] as? Int {
                            metadata["completion_tokens"] = .number(Double(output))
                        }
                    }
                    if let status = response["status"] as? String {
                        metadata["finish_reason"] = .string(status)
                    }
                    if accumulatedText.isEmpty, let items = response["output"] as? [[String: Any]] {
                        for item in items {
                            if let content = item["content"] as? [[String: Any]] {
                                for c in content {
                                    if let text = c["text"] as? String {
                                        accumulatedText += text
                                    }
                                }
                            }
                        }
                    }
                }

            case "response.incomplete":
                if let response = event["response"] as? [String: Any] {
                    if let m = response["model"] as? String { resolvedModel = m }
                    if let usage = response["usage"] as? [String: Any] {
                        if let input = usage["input_tokens"] as? Int {
                            metadata["prompt_tokens"] = .number(Double(input))
                        }
                        if let output = usage["output_tokens"] as? Int {
                            metadata["completion_tokens"] = .number(Double(output))
                        }
                    }
                }

            case "error":
                let msg = event["message"] as? String ?? "Unknown SSE error"
                throw CodexSSEError.streamError(msg)

            default:
                break
            }
        }

        return ProviderPlan(
            sourceBackend: backendName,
            label: "codex-plan",
            finalText: accumulatedText.isEmpty ? nil : accumulatedText,
            model: resolvedModel,
            toolRequests: toolRequests,
            metadata: metadata
        )
    }

    // MARK: - Helpers

    private func parseArguments(_ raw: String?) -> [String: JSONValue] {
        guard let raw, !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            if let raw, !raw.isEmpty {
                return ["_raw_arguments": .string(raw), "_parse_error": .bool(true)]
            }
            return [:]
        }
        return parsed
    }

    private func errorPlan(_ message: String, errorType: String) -> ProviderPlan {
        ProviderPlan(
            sourceBackend: backendName,
            label: "codex-provider-error",
            finalText: message,
            model: model,
            toolRequests: [],
            metadata: [
                "error_type": .string(errorType),
                "error": .string(message),
            ]
        )
    }

    private func jsonValueToString(_ dict: [String: JSONValue]) -> String {
        guard let data = try? JSONEncoder().encode(dict) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func jsonValueToNative(_ dict: [String: JSONValue]) -> Any {
        guard let data = try? JSONEncoder().encode(dict),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return [String: Any]()
        }
        return obj
    }
}

enum CodexSSEError: LocalizedError {
    case streamError(String)

    var errorDescription: String? {
        switch self {
        case .streamError(let msg): "SSE error: \(msg)"
        }
    }
}
