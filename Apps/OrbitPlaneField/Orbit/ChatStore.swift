import Foundation
import CryptoKit

final class ChatStore {
    private let chatDir: URL
    private let encryptionKey: SymmetricKey
    private let username: String

    init?(username: String) {
        guard let hashHex = KeychainManager.read(account: username),
              let keyData = Data(hexString: hashHex) else {
            return nil
        }

        self.encryptionKey = SymmetricKey(data: keyData)
        self.username = username

        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.chatDir = appSupport.appendingPathComponent("chat_history", isDirectory: true)
        try? FileManager.default.createDirectory(at: chatDir, withIntermediateDirectories: true)
    }

    // MARK: - Session Index

    private var indexURL: URL {
        chatDir.appendingPathComponent("\(username)_sessions.enc")
    }

    func loadSessions() -> [ChatSession] {
        decryptLoad(from: indexURL) ?? []
    }

    func saveSessions(_ sessions: [ChatSession]) {
        encryptSave(sessions, to: indexURL)
    }

    // MARK: - Per-Session Messages

    private func messageURL(for sessionId: UUID) -> URL {
        chatDir.appendingPathComponent("\(username)_\(sessionId.uuidString).enc")
    }

    func loadMessages(for sessionId: UUID) -> [ChatMessage] {
        decryptLoad(from: messageURL(for: sessionId)) ?? []
    }

    func saveMessages(_ messages: [ChatMessage], for sessionId: UUID) {
        let nonEmpty = messages.filter { !$0.content.isEmpty }
        encryptSave(nonEmpty, to: messageURL(for: sessionId))
    }

    func deleteSession(_ sessionId: UUID) {
        try? FileManager.default.removeItem(at: messageURL(for: sessionId))
    }

    // MARK: - Migration

    private var legacyURL: URL {
        chatDir.appendingPathComponent("\(username).enc")
    }

    func migrateIfNeeded() -> (session: ChatSession, messages: [ChatMessage])? {
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return nil }

        guard let messages: [ChatMessage] = decryptLoad(from: legacyURL),
              !messages.isEmpty else {
            try? FileManager.default.removeItem(at: legacyURL)
            return nil
        }

        let title = messages.first(where: { $0.role == .user })
            .map { String($0.content.prefix(30)) } ?? "Chat"
        let session = ChatSession(title: title)

        saveMessages(messages, for: session.id)
        try? FileManager.default.removeItem(at: legacyURL)

        return (session, messages)
    }

    // MARK: - Crypto Helpers

    private func decryptLoad<T: Decodable>(from url: URL) -> T? {
        guard let encrypted = try? Data(contentsOf: url) else { return nil }
        do {
            let box = try AES.GCM.SealedBox(combined: encrypted)
            let decrypted = try AES.GCM.open(box, using: encryptionKey)
            return try JSONDecoder().decode(T.self, from: decrypted)
        } catch {
            return nil
        }
    }

    private func encryptSave<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value),
              let sealed = try? AES.GCM.seal(data, using: encryptionKey),
              let combined = sealed.combined else {
            return
        }
        try? combined.write(to: url, options: .completeFileProtection)
    }
}

private extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        guard len > 0 else { return nil }

        var data = Data(capacity: len)
        var index = hexString.startIndex

        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
