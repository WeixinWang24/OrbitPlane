# Orbit2 Python Backend Interface Reference for SwiftUI Agent

This document summarizes the current Orbit2 Python-based backend and the practical interface surface a SwiftUI frontend can build against.

It reflects the current Orbit2 repo at:

```text
/Volumes/2TB/Dev/Orbit2
```

The most important conclusion: **Orbit2 currently has a strong Python runtime core, CLI harness, SQLite transcript store, provider adapters, and read-only web inspector, but it does not yet expose a stable mobile-facing REST API.** A SwiftUI frontend should therefore target a small bridge layer over the Python runtime rather than assume a complete HTTP backend already exists.

## 1. Architecture Snapshot

Current Orbit2 backend layers:

```text
Operation Surface
  -> CLI harness
  -> Web inspector
  -> future SwiftUI bridge / local HTTP bridge

Host Runtime Nucleus
  -> SessionManager
  -> transcript orchestration
  -> provider roundtrips
  -> tool-call loop

Provider Layer
  -> CodexBackend
  -> OpenAICompatibleBackend for vLLM

Knowledge Surface
  -> StructuredContextAssembler
  -> runtime/context/capability/workspace instruction fragments

Capability Surface
  -> CapabilityRegistry
  -> CapabilityBoundary
  -> native filesystem tools
  -> MCP-attached tools
  -> progressive exposure
  -> approval/governance

Store Boundary
  -> SQLiteSessionStore
  -> .runtime/sessions.db
```

Primary Python files:

```text
src/core/runtime/models.py
src/core/runtime/session.py
src/core/store/sqlite.py
src/core/providers/openai_compatible.py
src/core/providers/codex.py
src/config/runtime.py
src/operation/cli/harness.py
src/operation/inspector/web_inspector.py
src/capability/*
```

## 2. Runtime Root and Store

Runtime root resolution lives in `src/config/runtime.py`.

Priority:

```text
explicit runtime root
  -> ORBIT2_RUNTIME_ROOT
  -> repo root
```

Default runtime files:

```text
<runtime-root>/.runtime/sessions.db
<runtime-root>/.runtime/code_intel.db
<runtime-root>/.runtime/agent_runtime.toml
<runtime-root>/.runtime/openai_oauth_credentials.json
```

For the current repo, the default store is:

```text
/Volumes/2TB/Dev/Orbit2/.runtime/sessions.db
```

SwiftUI frontend implication:

- The Python backend is stateful through SQLite.
- A read-only frontend can inspect the SQLite store.
- A write/interactive frontend should call a Python bridge that uses `SessionManager`, not write messages directly into SQLite.

## 3. Core Data Models

Defined in `src/core/runtime/models.py`.

### Session

```swift
struct OrbitSession: Codable, Identifiable {
    var id: String { sessionId }
    var sessionId: String
    var backendName: String
    var systemPrompt: String?
    var status: String
    var createdAt: Date
    var updatedAt: Date
    var metadata: [String: JSONValue]
}
```

Python fields:

```text
session_id: str
backend_name: str
system_prompt: str?
status: "active" | "completed"
created_at: datetime
updated_at: datetime
metadata: dict
```

### ConversationMessage

```swift
struct OrbitMessage: Codable, Identifiable {
    var id: String { messageId }
    var messageId: String
    var sessionId: String
    var role: String
    var content: String
    var turnIndex: Int
    var createdAt: Date
    var metadata: [String: JSONValue]
}
```

Python fields:

```text
message_id: str
session_id: str
role: "system" | "user" | "assistant" | "tool"
content: str
turn_index: int
created_at: datetime
metadata: dict
```

### ExecutionPlan

`SessionManager.run_turn` returns an `ExecutionPlan`.

```swift
struct ProviderPlan: Codable {
    var sourceBackend: String
    var label: String
    var finalText: String?
    var model: String
    var metadata: [String: JSONValue]
    var toolRequests: [ToolRequest]
}
```

Python fields:

```text
source_backend: str
plan_label: str
final_text: str?
model: str
metadata: dict
tool_requests: list[ToolRequest]
```

### ToolRequest

```swift
struct ToolRequest: Codable {
    var toolCallId: String
    var toolName: String
    var arguments: [String: JSONValue]
    var providerItemId: String?
}
```

Python fields:

```text
tool_call_id: str
tool_name: str
arguments: dict
provider_item_id: str?
```

## 4. SQLite Store Schema

Implemented by `SQLiteSessionStore`.

### `sessions`

```sql
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY,
    backend_name TEXT NOT NULL,
    system_prompt TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    metadata_json TEXT NOT NULL DEFAULT '{}'
);
```

### `messages`

```sql
CREATE TABLE messages (
    message_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    turn_index INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    metadata_json TEXT NOT NULL DEFAULT '{}',
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);
```

Index:

```sql
CREATE INDEX idx_messages_session
    ON messages(session_id, turn_index);
```

SwiftUI read-only usage:

- List sessions ordered by `created_at DESC`.
- List messages by `session_id`, ordered by `turn_index ASC`.
- Decode `metadata_json` as flexible JSON.

Do not mutate this database directly from SwiftUI for chat turns. Use a bridge to `SessionManager`.

## 5. SessionManager API

`src/core/runtime/session.py` owns interactive backend execution.

Important methods:

```python
create_session(system_prompt: str | None = None) -> Session
get_session(session_id: str) -> Session
list_sessions() -> list[Session]
list_messages(session_id: str) -> list[ConversationMessage]
delete_all_sessions() -> int
run_turn(session_id: str, user_input: str, on_partial_text=None) -> ExecutionPlan
```

`run_turn` behavior:

1. Load session.
2. Save user message.
3. Assemble provider-facing context.
4. Call provider.
5. If provider returns tool calls, execute through `CapabilityBoundary`.
6. Save assistant/tool messages.
7. Continue provider/tool loop up to `MAX_TOOL_TURNS`.
8. Save final assistant message when available.
9. Update session timestamp.

SwiftUI bridge implication:

The frontend should call one backend operation:

```text
POST /sessions/{session_id}/turn
```

and let Python own the whole provider/tool loop.

## 6. Provider Backends

Provider abstraction:

```python
ExecutionBackend.plan_from_messages(request, on_partial_text=None) -> ExecutionPlan
```

### vLLM / OpenAI-compatible

File:

```text
src/core/providers/openai_compatible.py
```

Behavior:

- Uses OpenAI-compatible Chat Completions.
- Default base URL: `http://localhost:8000/v1`.
- Calls `client.chat.completions.create`.
- Supports `api_key`.
- Supports Basic Auth via `basic_auth_username` / `basic_auth_password`.
- Normalizes final text, tool calls, usage, and provider errors into `ExecutionPlan`.

Config variables:

```text
ORBIT2_PROVIDER_MODEL
ORBIT2_VLLM_BASE_URL
ORBIT2_VLLM_API_KEY
ORBIT2_VLLM_USERNAME
ORBIT2_VLLM_PASSWORD
```

For remote vLLM, the expected path is:

```text
SwiftUI / Python bridge
  -> http://localhost:8000/v1/chat/completions
  -> SSH tunnel
  -> remote vLLM
```

SSH tunnel is external to provider code.

### Codex

File:

```text
src/core/providers/codex.py
```

Behavior:

- Endpoint: `https://chatgpt.com/backend-api/codex/responses`.
- Uses bearer token credential.
- Default credential file: `.runtime/openai_oauth_credentials.json`.
- Uses SSE.
- Normalizes final text, tool calls, usage, response ids, and errors into `ExecutionPlan`.

Current local credential source already documented in:

```text
Orbit/docs/orbit2-ssh-vllm-and-codex-pkce-guide.md
```

Do not print or commit credentials.

## 7. CLI Harness

File:

```text
src/operation/cli/harness.py
```

The CLI is currently the main interactive operator surface.

Backend selection:

```text
--backend codex
--backend vllm
```

Runtime root:

```text
--runtime-root <path>
```

Obsidian attachment:

```text
--obsidian-vault-root <path>
```

Interactive commands:

```text
/quit
/history
/clear
/sessions
/switch
/new
/delete-all
/reset-permission
```

SwiftUI implication:

- The CLI is not a mobile API.
- It is the best reference for how to construct `SessionManager`.
- A future bridge should reuse `_build_backend`, `_build_capability_boundary`, `SQLiteSessionStore`, and `StructuredContextAssembler` patterns.

## 8. Web Inspector

File:

```text
src/operation/inspector/web_inspector.py
```

The web inspector is read-only projection over the SQLite store.

Server:

```text
ThreadingHTTPServer
GET /
```

Query parameters:

```text
session_id=<session_id>
tab=transcript | assembly | exposure | debug
right_tab=metadata | raw
```

Current tabs:

- Transcript
- Assembly
- Exposure
- Debug
- Metadata
- Raw

Important limitation:

The inspector returns HTML, not JSON API responses. SwiftUI should not treat it as a stable API. It is useful as a design reference and debugging surface.

## 9. Capability and Tool System

Files:

```text
src/capability/models.py
src/capability/registry.py
src/capability/boundary.py
src/capability/tools/*
src/capability/mcp/*
src/capability/mcp_servers/*
```

Important data contracts:

```text
ToolDefinition
CapabilityMetadata
ToolResult
CapabilityResult
GovernanceOutcome
```

Capability layers:

```text
raw_primitive
structured_primitive
toolchain
workflow
```

Capability boundary responsibilities:

- Look up tool by name.
- Deny unknown tools.
- Enforce workspace boundary.
- Deny protected locations such as `.runtime`, `.env`, `.envrc`, `.git`.
- Validate arguments against tool schema.
- Route approval-gated calls through approval policy/interactor.
- Execute tool.
- Return governed `CapabilityResult`.

SwiftUI implication:

- Tool execution should remain in Python.
- SwiftUI can display tool calls and tool results from message metadata.
- Approval UI can later become a SwiftUI surface, but current approval interactor is CLI-based.

## 10. Message Metadata Worth Displaying

Assistant messages may include:

```text
source_backend
model
tool_calls
tool_overlap_notice
assembly_envelope
tool_loop_exhausted
```

Tool messages may include:

```text
tool_call_id
tool_name
ok
governance_outcome
workflow_decision
reveal_request markers
```

Workflow decision metadata may include:

```text
message_type
workflow_run_id
decision_id
workflow_name
selected_option_id
branch_type
status
```

SwiftUI should treat metadata as flexible JSON, not fixed schema.

## 11. Recommended SwiftUI Bridge API

Because Orbit2 does not yet expose a stable REST API, implement a small local Python bridge if SwiftUI needs live interaction.

Recommended minimal JSON endpoints:

```text
GET  /health
GET  /sessions
POST /sessions
GET  /sessions/{session_id}
GET  /sessions/{session_id}/messages
POST /sessions/{session_id}/turn
POST /sessions/delete-all
```

Optional later:

```text
GET  /capabilities
GET  /runtime
GET  /debug/assembly/{session_id}
GET  /debug/exposure/{session_id}
POST /approval/{request_id}
```

### `GET /health`

Response:

```json
{
  "ok": true,
  "backend": "codex",
  "runtime_root": "/Volumes/2TB/Dev/Orbit2",
  "db_path": "/Volumes/2TB/Dev/Orbit2/.runtime/sessions.db"
}
```

### `POST /sessions`

Request:

```json
{
  "system_prompt": "You are a helpful assistant."
}
```

Response: `Session`.

### `POST /sessions/{session_id}/turn`

Request:

```json
{
  "content": "user message"
}
```

Response:

```json
{
  "plan": {
    "source_backend": "openai-codex",
    "plan_label": "openai-codex-final-text",
    "final_text": "...",
    "model": "...",
    "metadata": {},
    "tool_requests": []
  },
  "messages": []
}
```

For streaming, prefer Server-Sent Events later:

```text
POST /sessions/{session_id}/turn/stream
```

Events:

```text
partial_text
message_saved
plan_done
error
```

## 12. SwiftUI Frontend State Model

Recommended frontend state:

```swift
@MainActor
final class OrbitBackendClient: ObservableObject {
    @Published var sessions: [OrbitSession] = []
    @Published var selectedSession: OrbitSession?
    @Published var messages: [OrbitMessage] = []
    @Published var isRunningTurn = false
    @Published var lastError: String?
}
```

Recommended UI areas:

- Session sidebar.
- Transcript view.
- Composer input.
- Provider/runtime status.
- Tool activity drawer.
- Metadata/debug inspector sheet.
- Credential/runtime settings screen.

Keep first slice simple:

1. List sessions.
2. Select session.
3. Show transcript.
4. Send one turn.
5. Refresh messages after the turn completes.

Streaming, approval UI, and capability exposure controls can come after the stable bridge is in place.

## 13. Current Non-Goals

Do not assume these exist yet:

- Stable REST API in Orbit2 Python backend.
- Mobile-ready authentication service.
- Direct Swift access to Python `SessionManager`.
- JSON version of the web inspector.
- Swift-native tool execution.
- Swift-native transcript store writer.

Do not build SwiftUI around the HTML inspector as a backend API. Use it only for design/debug reference.

## 14. Implementation Advice for Swift Agent

Use the current Swift provider docs together with this backend reference:

```text
Orbit/docs/swift-provider-connection-reference.md
Orbit/docs/orbit2-ssh-vllm-and-codex-pkce-guide.md
Orbit/docs/orbit2-python-backend-interface-reference.md
```

Suggested implementation order:

1. Build Swift data models matching `Session`, `ConversationMessage`, and `ExecutionPlan`.
2. Add a local configurable backend base URL.
3. Implement read-only SQLite or JSON bridge client for sessions/messages.
4. Add a Python local HTTP bridge over `SessionManager`.
5. Implement `POST /sessions/{id}/turn` without streaming first.
6. Add streaming partial text later.
7. Add metadata/tool-result display.
8. Add approval UI only after Python exposes approval requests over the bridge.

## 15. Security Notes

- Never commit `.runtime/openai_oauth_credentials.json`.
- Never commit imported credentials.
- Do not write credentials into Swift source or Xcode settings.
- Use Keychain for iOS credentials.
- Treat message metadata as potentially sensitive.
- Treat paste/cache/session-history files as sensitive during debugging.

## 16. Bottom Line

The Python backend is ready to be wrapped, not replaced. For SwiftUI, build a thin frontend and a thin local bridge around `SessionManager`; let Python continue owning provider calls, transcript persistence, tool execution, governance, and capability exposure.
