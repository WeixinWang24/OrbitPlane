import Foundation

@Observable
final class ChatSessionManager {
    private(set) var sessions: [ChatSession] = []
    private(set) var currentSessionId: UUID

    private let store: ChatStore?

    init(store: ChatStore?) {
        self.store = store

        var loaded: [ChatSession]
        var activeId: UUID

        if let store, let migrated = store.migrateIfNeeded() {
            loaded = [migrated.session]
            activeId = migrated.session.id
            store.saveSessions(loaded)
        } else {
            loaded = store?.loadSessions() ?? []
            if let first = loaded.first {
                activeId = first.id
            } else {
                let session = ChatSession()
                loaded = [session]
                activeId = session.id
                store?.saveSessions(loaded)
            }
        }

        self.sessions = loaded
        self.currentSessionId = activeId
    }

    var currentSession: ChatSession? {
        sessions.first { $0.id == currentSessionId }
    }

    @discardableResult
    func createSession() -> UUID {
        let session = ChatSession()
        sessions.insert(session, at: 0)
        currentSessionId = session.id
        store?.saveSessions(sessions)
        return session.id
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        store?.deleteSession(id)

        if currentSessionId == id {
            if sessions.isEmpty {
                createSession()
            } else {
                currentSessionId = sessions[0].id
            }
        }
        store?.saveSessions(sessions)
    }

    func switchSession(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        currentSessionId = id
    }

    func loadCurrentMessages() -> [ChatMessage] {
        store?.loadMessages(for: currentSessionId) ?? []
    }

    func saveCurrentMessages(_ messages: [ChatMessage]) {
        store?.saveMessages(messages, for: currentSessionId)
        updateSessionMetadata(messages: messages)
    }

    private func updateSessionMetadata(messages: [ChatMessage]) {
        guard let idx = sessions.firstIndex(where: { $0.id == currentSessionId }) else { return }
        sessions[idx].updatedAt = Date()
        if sessions[idx].title == "New Chat",
           let first = messages.first(where: { $0.role == .user }),
           !first.content.isEmpty {
            sessions[idx].title = String(first.content.prefix(30))
        }
        store?.saveSessions(sessions)
    }
}
