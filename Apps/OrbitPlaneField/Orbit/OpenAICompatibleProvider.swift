import Foundation

final class OpenAICompatibleProvider: AgentProvider, @unchecked Sendable {
    let settings: ProviderSettings
    let session: URLSession

    var backendName: String { "openai-compatible" }

    init(settings: ProviderSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func plan(
        from request: TurnRequest,
        onPartialText: (@Sendable (String) -> Void)? = nil
    ) async -> ProviderPlan {
        let url = settings.baseURL.appendingPathComponent("chat/completions")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = settings.apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else if let username = settings.basicAuthUsername,
                  let password = settings.basicAuthPassword {
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                urlRequest.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        let payload = buildPayload(from: request)

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return errorPlan("Failed to encode request: \(error.localizedDescription)", errorType: "encode_failure")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            return errorPlan("Connection failed: \(error.localizedDescription)", errorType: "connection_failure")
        }

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return errorPlan("Authentication failed (\(httpResponse.statusCode)): \(body)", errorType: "auth_failure")
            }
            return errorPlan("HTTP \(httpResponse.statusCode): \(body)", errorType: "http_error")
        }

        return decodeResponse(data)
    }

    // MARK: - Request Encoding

    private func buildPayload(from request: TurnRequest) -> [String: Any] {
        var messages: [[String: Any]] = []

        if let system = request.system {
            messages.append(["role": "system", "content": system])
        }

        for msg in request.messages {
            var entry: [String: Any] = ["role": msg.role]

            if let content = msg.content {
                entry["content"] = content
            }

            if let toolCallID = msg.toolCallID {
                entry["tool_call_id"] = toolCallID
            }

            if let toolCalls = msg.toolCalls {
                entry["tool_calls"] = toolCalls.map { tc in
                    [
                        "id": tc.id,
                        "type": "function",
                        "function": [
                            "name": tc.functionName,
                            "arguments": jsonValueToString(tc.arguments)
                        ] as [String: Any]
                    ] as [String: Any]
                }
            }

            messages.append(entry)
        }

        var payload: [String: Any] = [
            "model": settings.model,
            "max_tokens": settings.maxTokens,
            "messages": messages
        ]

        if let tools = request.toolDefinitions, !tools.isEmpty {
            payload["tools"] = tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": jsonValueToNative(tool.parameters)
                    ] as [String: Any]
                ] as [String: Any]
            }
        }

        return payload
    }

    // MARK: - Response Decoding

    private func decodeResponse(_ data: Data) -> ProviderPlan {
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return errorPlan("Response is not a JSON object", errorType: "decode_failure")
            }
            json = parsed
        } catch {
            return errorPlan("JSON decode failed: \(error.localizedDescription)", errorType: "decode_failure")
        }

        let model = json["model"] as? String ?? settings.model

        var metadata: [String: JSONValue] = [:]

        if let usage = json["usage"] as? [String: Any] {
            if let prompt = usage["prompt_tokens"] as? Int {
                metadata["prompt_tokens"] = .number(Double(prompt))
            }
            if let completion = usage["completion_tokens"] as? Int {
                metadata["completion_tokens"] = .number(Double(completion))
            }
        }

        guard let choices = json["choices"] as? [[String: Any]], let first = choices.first else {
            return ProviderPlan(
                sourceBackend: backendName,
                label: "empty-choices",
                finalText: nil,
                model: model,
                toolRequests: [],
                metadata: metadata
            )
        }

        if let finishReason = first["finish_reason"] as? String {
            metadata["finish_reason"] = .string(finishReason)
        }

        guard let message = first["message"] as? [String: Any] else {
            return errorPlan("Missing message in choice", errorType: "decode_failure")
        }

        let finalText = message["content"] as? String
        var toolRequests: [ToolRequest] = []

        if let rawToolCalls = message["tool_calls"] as? [[String: Any]] {
            for tc in rawToolCalls {
                guard let id = tc["id"] as? String,
                      let function = tc["function"] as? [String: Any],
                      let name = function["name"] as? String else {
                    continue
                }

                let arguments = parseToolArguments(function["arguments"] as? String)
                toolRequests.append(ToolRequest(
                    toolCallID: id,
                    toolName: name,
                    arguments: arguments
                ))
            }
        }

        return ProviderPlan(
            sourceBackend: backendName,
            label: "openai-compatible-plan",
            finalText: finalText,
            model: model,
            toolRequests: toolRequests,
            metadata: metadata
        )
    }

    // MARK: - Tool Argument Parsing

    private func parseToolArguments(_ raw: String?) -> [String: JSONValue] {
        guard let raw, !raw.isEmpty else { return [:] }

        guard let data = raw.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            return [
                "_raw_arguments": .string(raw),
                "_parse_error": .bool(true)
            ]
        }

        return parsed
    }

    // MARK: - Error Normalization

    private func errorPlan(_ message: String, errorType: String) -> ProviderPlan {
        ProviderPlan(
            sourceBackend: backendName,
            label: "openai-compatible-provider-error",
            finalText: message,
            model: settings.model,
            toolRequests: [],
            metadata: [
                "error_type": .string(errorType),
                "error": .string(message),
                "base_url": .string(settings.baseURL.absoluteString)
            ]
        )
    }

    // MARK: - JSON Helpers

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
