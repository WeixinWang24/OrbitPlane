import SwiftUI

@Observable
@MainActor
final class OrbitBackendClient {
    var sessions: [OrbitSession] = []
    var selectedSessionId: String?
    var messages: [OrbitMessage] = []
    var isRunningTurn = false
    var isConnected = false
    var lastError: String?
    var backendName = "codex"

    var baseURL = "http://localhost:8080"

    var selectedSession: OrbitSession? {
        sessions.first { $0.sessionId == selectedSessionId }
    }

    init() {
        loadMockData()
        if let first = sessions.first {
            selectSession(first)
        }
    }

    func selectSession(_ session: OrbitSession) {
        selectedSessionId = session.sessionId
        messages = mockMessages(for: session.sessionId)
    }

    func sendMessage(_ content: String) {
        guard let sessionId = selectedSessionId else { return }

        let userMessage = OrbitMessage(
            messageId: UUID().uuidString,
            sessionId: sessionId,
            role: .user,
            content: content,
            turnIndex: (messages.last?.turnIndex ?? 0) + 1,
            createdAt: Date(),
            metadata: [:]
        )
        messages.append(userMessage)
        isRunningTurn = true

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            let backend = selectedSession?.backendName ?? "unknown"
            let response = OrbitMessage(
                messageId: UUID().uuidString,
                sessionId: sessionId,
                role: .assistant,
                content: "This is a simulated response from the **\(backend)** backend. Connect the Python bridge at `\(baseURL)` to enable live interaction with Orbit2 runtime.",
                turnIndex: (messages.last?.turnIndex ?? 0) + 1,
                createdAt: Date(),
                metadata: [
                    "source_backend": .string(backend),
                    "model": .string("mock-preview"),
                ]
            )
            messages.append(response)
            isRunningTurn = false
        }
    }

    func createSession() {
        let session = OrbitSession(
            sessionId: "sess-\(UUID().uuidString.prefix(8))",
            backendName: backendName,
            systemPrompt: "You are a helpful AI assistant.",
            status: "active",
            createdAt: Date(),
            updatedAt: Date(),
            metadata: [:]
        )
        sessions.insert(session, at: 0)
        selectSession(session)
    }

    // MARK: - Mock Data

    private func loadMockData() {
        let now = Date()
        sessions = [
            OrbitSession(
                sessionId: "sess-a1b2c3d4",
                backendName: "codex",
                systemPrompt: "You are a code review agent with security analysis capabilities.",
                status: "active",
                createdAt: now.addingTimeInterval(-7200),
                updatedAt: now.addingTimeInterval(-120),
                metadata: [:]
            ),
            OrbitSession(
                sessionId: "sess-e5f6g7h8",
                backendName: "vllm",
                systemPrompt: "You manage data processing pipelines.",
                status: "active",
                createdAt: now.addingTimeInterval(-3600),
                updatedAt: now.addingTimeInterval(-600),
                metadata: [:]
            ),
            OrbitSession(
                sessionId: "sess-i9j0k1l2",
                backendName: "codex",
                systemPrompt: nil,
                status: "completed",
                createdAt: now.addingTimeInterval(-86400),
                updatedAt: now.addingTimeInterval(-86400),
                metadata: [:]
            ),
        ]
    }

    private func mockMessages(for sessionId: String) -> [OrbitMessage] {
        let now = Date()
        switch sessionId {
        case "sess-a1b2c3d4":
            return [
                OrbitMessage(messageId: "m-001", sessionId: sessionId, role: .system,
                             content: "You are a code review agent with security analysis capabilities.",
                             turnIndex: 0, createdAt: now.addingTimeInterval(-7200), metadata: [:]),
                OrbitMessage(messageId: "m-002", sessionId: sessionId, role: .user,
                             content: "Review the authentication middleware in src/auth/middleware.py for potential security issues.",
                             turnIndex: 1, createdAt: now.addingTimeInterval(-7100), metadata: [:]),
                OrbitMessage(messageId: "m-003", sessionId: sessionId, role: .assistant,
                             content: "I'll analyze the authentication middleware. Let me read the file first.",
                             turnIndex: 2, createdAt: now.addingTimeInterval(-7090),
                             metadata: ["source_backend": .string("openai-codex"), "model": .string("codex-2025-03")]),
                OrbitMessage(messageId: "m-004", sessionId: sessionId, role: .tool,
                             content: "read_file: src/auth/middleware.py (245 lines)",
                             turnIndex: 3, createdAt: now.addingTimeInterval(-7085),
                             metadata: ["tool_name": .string("read_file"), "ok": .bool(true)]),
                OrbitMessage(messageId: "m-005", sessionId: sessionId, role: .assistant,
                             content: "I've reviewed the authentication middleware and found 3 issues:\n\n1. **Session token storage** — Tokens are stored in plaintext cookies without the `HttpOnly` flag, making them vulnerable to XSS.\n\n2. **Missing rate limiting** — The login endpoint has no rate limiting, allowing brute-force attacks.\n\n3. **Weak CSRF protection** — The CSRF token is derived from the session ID using a predictable hash.",
                             turnIndex: 4, createdAt: now.addingTimeInterval(-7080),
                             metadata: ["source_backend": .string("openai-codex"), "model": .string("codex-2025-03")]),
                OrbitMessage(messageId: "m-006", sessionId: sessionId, role: .user,
                             content: "Can you suggest fixes for the session token issue?",
                             turnIndex: 5, createdAt: now.addingTimeInterval(-300), metadata: [:]),
                OrbitMessage(messageId: "m-007", sessionId: sessionId, role: .assistant,
                             content: "Here's the recommended fix for secure session token handling:\n\n```python\nresponse.set_cookie(\n    'session_token',\n    value=token,\n    httponly=True,\n    secure=True,\n    samesite='Lax',\n    max_age=3600\n)\n```\n\nThis adds `HttpOnly` to prevent JavaScript access, `Secure` to ensure HTTPS-only transmission, and `SameSite=Lax` for CSRF mitigation.",
                             turnIndex: 6, createdAt: now.addingTimeInterval(-290),
                             metadata: ["source_backend": .string("openai-codex"), "model": .string("codex-2025-03")]),
            ]
        case "sess-e5f6g7h8":
            return [
                OrbitMessage(messageId: "m-010", sessionId: sessionId, role: .system,
                             content: "You manage data processing pipelines.",
                             turnIndex: 0, createdAt: now.addingTimeInterval(-3600), metadata: [:]),
                OrbitMessage(messageId: "m-011", sessionId: sessionId, role: .user,
                             content: "Process the latest batch from the ingestion queue.",
                             turnIndex: 1, createdAt: now.addingTimeInterval(-3500), metadata: [:]),
                OrbitMessage(messageId: "m-012", sessionId: sessionId, role: .assistant,
                             content: "Starting batch processing. I'll check the queue status and begin processing records sequentially.",
                             turnIndex: 2, createdAt: now.addingTimeInterval(-3490),
                             metadata: ["source_backend": .string("vllm-local"), "model": .string("qwen-2.5-72b")]),
            ]
        default:
            return []
        }
    }

    // MARK: - Future API (stubs for Python bridge)

    func checkHealth() async {
        // TODO: GET \(baseURL)/health
    }

    func fetchSessions() async {
        // TODO: GET \(baseURL)/sessions
    }

    func fetchMessages(sessionId: String) async {
        // TODO: GET \(baseURL)/sessions/\(sessionId)/messages
    }

    func runTurn(sessionId: String, content: String) async {
        // TODO: POST \(baseURL)/sessions/\(sessionId)/turn
    }
}
