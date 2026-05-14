# Swift Agent Reference: Orbit2 vLLM / OpenAI Provider Connection Chain

This document summarizes the current Orbit2 vLLM and OpenAI provider connection model for a Swift project development agent. The goal is not to copy Orbit2's Python code directly, but to reuse its communication principles, boundaries, and implementation sequence.

## 1. Core Principle

Orbit2 treats model providers as protocol adapters.

The provider layer should only handle:

- Provider configuration.
- Request payload construction.
- HTTP or SSE communication.
- Response normalization.
- Tool-call extraction.
- Transport/provider error normalization.

The provider layer should not handle:

- SSH tunnel lifecycle.
- Multi-turn session orchestration.
- Transcript persistence.
- Tool execution.
- Approval/governance.
- UI or CLI rendering.

In a Swift project, keep the same separation:

```text
Swift App / Agent Runtime
  -> ProviderConfigResolver
  -> ProviderProtocol
    -> OpenAICompatibleProvider
    -> OpenAICodexProvider / OpenAIResponsesProvider
  -> ProviderPlan
```

## 2. Orbit2 Provider Shapes

Orbit2 currently has two relevant provider paths.

### vLLM Path

The vLLM path uses an OpenAI-compatible Chat Completions backend:

```text
Orbit2 CLI / Runtime
  -> OpenAICompatibleBackend
  -> OpenAI SDK Chat Completions
  -> http://localhost:<port>/v1/chat/completions
  -> SSH tunnel
  -> remote vLLM server
```

Important: vLLM is not treated as a custom protocol. It is treated as an OpenAI-compatible HTTP service.

### OpenAI / Codex Path

Orbit2's Codex backend is a separate backend:

```text
Orbit2 CLI / Runtime
  -> CodexBackend
  -> https://chatgpt.com/backend-api/codex/responses
  -> SSE stream
  -> normalized ExecutionPlan
```

The Codex path uses bearer-token authentication and Server-Sent Events. It is not the same wire protocol as the vLLM Chat Completions path.

## 3. vLLM Connection Through SSH Tunnel

For vLLM, the SSH tunnel is an operator/runtime concern. The provider only sees a local OpenAI-compatible endpoint.

Example tunnel:

```bash
ssh -N -L 8000:<remote-vllm-host>:8080 <ssh-target>
```

Then configure the provider with:

```bash
export ORBIT2_VLLM_BASE_URL=http://localhost:8000/v1
export ORBIT2_PROVIDER_MODEL=<served-model-name>
```

The Swift provider should send:

```text
POST http://localhost:8000/v1/chat/completions
```

Do not embed SSH logic inside the provider. This keeps the provider reusable across:

- Local vLLM.
- Remote vLLM over SSH tunnel.
- OpenAI-compatible gateways.
- Local model servers such as LM Studio or Ollama-compatible bridges, if they expose the same API shape.

## 4. Configuration Model

Orbit2 resolves provider settings from explicit config, environment variables, then defaults.

Swift equivalent:

```swift
struct ProviderSettings {
    var model: String
    var baseURL: URL
    var apiKey: String?
    var basicAuthUsername: String?
    var basicAuthPassword: String?
    var maxTokens: Int
}
```

Recommended environment variables:

```text
ORBIT2_PROVIDER_MODEL      model name
ORBIT2_VLLM_BASE_URL       OpenAI-compatible base URL, for example http://localhost:8000/v1
ORBIT2_VLLM_API_KEY        optional API key
ORBIT2_VLLM_USERNAME       optional Basic Auth username
ORBIT2_VLLM_PASSWORD       optional Basic Auth password
```

Recommended defaults:

```text
model    gpt-5.5 or project-specific default
baseURL  http://localhost:8000/v1
apiKey   nil
```

If an OpenAI SDK or gateway requires an API key even for vLLM, Orbit2 uses `EMPTY` as a compatibility placeholder. With raw Swift `URLSession`, only send an Authorization header when the endpoint actually requires it.

## 5. Base URL Normalization

Normalize the base URL before building requests.

If the user provides:

```text
http://localhost:8000/v1/chat/completions
```

store:

```text
http://localhost:8000/v1
```

Then append:

```text
/chat/completions
```

This prevents double endpoint paths such as:

```text
/v1/chat/completions/chat/completions
```

Swift helper shape:

```swift
func normalizeOpenAIBaseURL(_ raw: String) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    while value.hasSuffix("/") {
        value.removeLast()
    }
    let suffix = "/chat/completions"
    if value.hasSuffix(suffix) {
        value.removeLast(suffix.count)
    }
    return value
}
```

## 6. Runtime Data Contracts

Keep provider input and output stable. Do not let raw API payloads spread through the app.

Suggested Swift request model:

```swift
struct TurnRequest {
    var system: String?
    var messages: [ProviderMessage]
    var toolDefinitions: [ToolDefinition]?
}

struct ProviderMessage {
    var role: String
    var content: String?
    var toolCalls: [ToolCall]?
    var toolCallID: String?
}
```

Suggested normalized output:

```swift
struct ProviderPlan {
    var sourceBackend: String
    var label: String
    var finalText: String?
    var model: String
    var toolRequests: [ToolRequest]
    var metadata: [String: JSONValue]
}

struct ToolRequest {
    var toolCallID: String
    var toolName: String
    var arguments: [String: JSONValue]
}
```

The runtime consumes `ProviderPlan`. It should not consume raw OpenAI response objects.

## 7. vLLM Chat Completions Request

The provider converts `TurnRequest` to an OpenAI Chat Completions payload.

Request:

```text
POST {baseURL}/chat/completions
Content-Type: application/json
Authorization: Bearer <apiKey>        optional
Authorization: Basic <base64>         optional, for Basic Auth gateways
```

Payload:

```json
{
  "model": "<model>",
  "max_tokens": 1024,
  "messages": [
    {"role": "system", "content": "You are helpful."},
    {"role": "user", "content": "Hello"}
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "read_file",
        "description": "Read a file.",
        "parameters": {
          "type": "object",
          "properties": {
            "path": {"type": "string"}
          },
          "required": ["path"]
        }
      }
    }
  ]
}
```

Only include `tools` when tools are available.

For messages:

- System prompt can be sent as the first `system` message.
- User and assistant messages map directly.
- Tool-result messages should be represented according to the OpenAI Chat Completions tool-message shape if the Swift runtime supports tool continuation.
- Assistant messages that contain tool calls should preserve tool call IDs so the next tool result can reference them.

## 8. vLLM Response Normalization

The provider should normalize the response into `ProviderPlan`.

Rules:

- `choices[0].message.content` becomes `finalText`.
- `choices[0].message.tool_calls` becomes `toolRequests`.
- `response.model` becomes `model`.
- `choices[0].finish_reason` goes into metadata.
- `usage.prompt_tokens` and `usage.completion_tokens` go into metadata when present.
- Empty `choices` becomes an empty-response plan.
- Malformed tool-call arguments should not crash the provider.

Malformed arguments handling:

```text
If JSON parsing succeeds:
  arguments = parsed dictionary

If JSON parsing fails:
  arguments = {
    "_raw_arguments": originalString,
    "_parse_error": true
  }
```

The provider returns tool requests. It must not execute tools.

Tool execution belongs to the runtime:

```text
ProviderPlan.toolRequests
  -> Runtime validates/governs tool calls
  -> Runtime executes tools
  -> Runtime appends tool result messages
  -> Runtime calls provider again
```

## 9. Error Normalization

Provider errors should become structured provider results or typed provider errors.

Recommended categories:

- Connection failure.
- HTTP non-2xx.
- Authentication failure.
- Decode failure.
- Empty choices.
- Tool argument parse failure.

Orbit2 returns provider errors as normalized plans with metadata. Swift can either return a `ProviderPlan` with an error label or throw a typed error that the runtime converts into a plan.

Recommended normalized fields:

```text
sourceBackend = "openai-compatible"
label         = "openai-compatible-provider-error"
finalText     = readable diagnostic
model         = configured model
metadata      = {
  "error_type": "...",
  "error": "...",
  "base_url": "..."
}
```

## 10. OpenAI / Codex SSE Path

If the Swift project also wants a Codex/OpenAI streaming backend, keep it separate from the vLLM Chat Completions provider.

Orbit2's Codex path:

```text
POST https://chatgpt.com/backend-api/codex/responses
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: text/event-stream
```

Payload shape:

```json
{
  "model": "<model>",
  "store": false,
  "stream": true,
  "input": [],
  "instructions": "...",
  "tools": [],
  "text": {
    "verbosity": "medium"
  }
}
```

SSE handling:

- Accumulate `response.output_text.delta` for streaming UI.
- Use completed output items to recover final text and function calls.
- Preserve provider item IDs when available.
- Normalize final output into the same `ProviderPlan` shape used by vLLM.

This allows runtime code to be backend-agnostic.

## 11. Swift Implementation Sequence

Recommended order for a Swift development agent:

1. Define `TurnRequest`, `ProviderMessage`, `ToolDefinition`, `ToolRequest`, and `ProviderPlan`.
2. Define `AgentProvider` protocol.
3. Define `ProviderSettings`.
4. Implement environment/config resolution.
5. Implement base URL normalization.
6. Implement `OpenAICompatibleProvider`.
7. Add Chat Completions request encoding.
8. Add Chat Completions response decoding.
9. Add tool-call argument parsing and malformed JSON fallback.
10. Add error normalization.
11. Add fake-server tests for final text, tool calls, empty choices, and malformed arguments.
12. Add operator documentation for SSH tunnel setup.
13. Add optional Codex/OpenAI SSE provider later, behind the same protocol.

## 12. Minimal Swift Skeleton

```swift
protocol AgentProvider {
    var backendName: String { get }

    func plan(
        from request: TurnRequest,
        onPartialText: ((String) -> Void)?
    ) async -> ProviderPlan
}

final class OpenAICompatibleProvider: AgentProvider {
    let settings: ProviderSettings
    let session: URLSession

    var backendName: String { "openai-compatible" }

    init(settings: ProviderSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func plan(
        from request: TurnRequest,
        onPartialText: ((String) -> Void)? = nil
    ) async -> ProviderPlan {
        // 1. Build URL: settings.baseURL + "/chat/completions"
        // 2. Encode messages and tools.
        // 3. Send request with URLSession.
        // 4. Decode response.
        // 5. Normalize content/tool calls/errors into ProviderPlan.
        fatalError("Implement provider transport")
    }
}
```

## 13. Acceptance Checklist

The Swift implementation is aligned with Orbit2's provider design when:

- vLLM connects through a local OpenAI-compatible URL, usually exposed by SSH tunnel.
- Provider code does not create or manage SSH tunnels.
- Provider code does not execute tools.
- Provider output is normalized into a stable project-local plan type.
- Runtime owns transcript, continuation, and tool execution.
- Base URL normalization prevents duplicate `/chat/completions`.
- Tool-call argument parse failure is recoverable.
- vLLM and OpenAI/Codex can be implemented as separate providers behind one protocol.

## 14. One-Sentence Summary

Expose remote vLLM through an external SSH tunnel as a local OpenAI-compatible endpoint, then implement a thin Swift provider that resolves config, calls Chat Completions, extracts final text and tool calls, and returns a normalized provider plan while leaving SSH lifecycle, sessions, transcript, and tool execution to the runtime.
