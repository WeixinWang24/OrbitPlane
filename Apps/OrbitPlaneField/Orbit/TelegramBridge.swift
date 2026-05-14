import Foundation

final class TelegramBridge: MessagingBridge, @unchecked Sendable {
    private let token: String
    private let baseURL: URL
    private let session: URLSession
    private let pollingTimeout: Int = 30

    private var allowedUserIds: Set<String>
    private var allowedChatId: String?
    private var botId: Int?
    private var botUsername: String?
    private var lastUpdateId: Int?
    private var pollingTask: Task<Void, Never>?
    private var continuation: AsyncStream<BridgeMessage>.Continuation?

    private(set) var isRunning = false

    init(token: String, allowedChatId: String? = nil, allowedUserIds: Set<String> = []) {
        self.token = token
        self.allowedChatId = allowedChatId
        self.allowedUserIds = allowedUserIds
        self.baseURL = URL(string: "https://api.telegram.org/bot\(token)")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(pollingTimeout + 10)
        self.session = URLSession(configuration: config)
    }

    func updateAllowedUsers(_ ids: Set<String>) {
        allowedUserIds = ids
    }

    // MARK: - MessagingBridge

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        await fetchBotInfo()

        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isRunning {
                await self.pollUpdates()
            }
        }
    }

    func stop() {
        isRunning = false
        pollingTask?.cancel()
        pollingTask = nil
        continuation?.finish()
        continuation = nil
    }

    func send(text: String, to chatId: String) async throws {
        let url = baseURL.appendingPathComponent("sendMessage")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "Markdown"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TelegramError.sendFailed(errorText)
        }
    }

    func messages() -> AsyncStream<BridgeMessage> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    // MARK: - Bot Identity

    private func fetchBotInfo() async {
        let url = baseURL.appendingPathComponent("getMe")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(TelegramResponse<TelegramUser>.self, from: data)
            if let bot = response.result {
                botId = bot.id
                botUsername = bot.username
            }
        } catch {}
    }

    // MARK: - Polling

    private func pollUpdates() async {
        var params: [String: Any] = [
            "timeout": pollingTimeout,
            "allowed_updates": ["message"]
        ]
        if let offset = lastUpdateId {
            params["offset"] = offset + 1
        }

        let url = baseURL.appendingPathComponent("getUpdates")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: params)
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(TelegramResponse<[TelegramUpdate]>.self, from: data)

            guard response.ok, let updates = response.result else { return }

            for update in updates {
                lastUpdateId = update.updateId

                guard let msg = update.message, let text = msg.text else { continue }

                // Skip messages from the bot itself
                if let botId, msg.from?.id == botId { continue }

                // Only accept messages from the configured group
                guard let allowed = allowedChatId, "\(msg.chat.id)" == allowed else { continue }

                let senderId = msg.from.map { "\($0.id)" } ?? ""

                if !allowedUserIds.isEmpty && !allowedUserIds.contains(senderId) {
                    continue
                }

                let isGroup = msg.chat.type == "group" || msg.chat.type == "supergroup"

                // Only accept group messages with @mention or reply to bot
                if !isGroup { continue }

                let mentioned = isBotMentioned(in: text, entities: msg.entities)
                let replied = msg.replyToMessage?.from?.id == botId

                if !mentioned && !replied { continue }

                let cleanText = stripBotMention(from: text)

                let bridgeMsg = BridgeMessage(
                    id: "\(msg.messageId)",
                    chatId: "\(msg.chat.id)",
                    senderId: senderId,
                    senderName: msg.from?.displayName ?? "Unknown",
                    text: cleanText,
                    date: Date(timeIntervalSince1970: TimeInterval(msg.date))
                )
                continuation?.yield(bridgeMsg)
            }
        } catch is CancellationError {
            return
        } catch {
            if isRunning {
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    // MARK: - Mention Detection

    private func isBotMentioned(in text: String, entities: [TelegramEntity]?) -> Bool {
        guard let username = botUsername else { return false }

        if let entities {
            for entity in entities where entity.type == "mention" {
                let start = text.index(text.startIndex, offsetBy: entity.offset, limitedBy: text.endIndex) ?? text.endIndex
                let end = text.index(start, offsetBy: entity.length, limitedBy: text.endIndex) ?? text.endIndex
                let mention = String(text[start..<end])
                if mention.lowercased() == "@\(username.lowercased())" {
                    return true
                }
            }
        }

        return text.lowercased().contains("@\(username.lowercased())")
    }

    private func stripBotMention(from text: String) -> String {
        guard let username = botUsername else { return text }
        let pattern = "@\(NSRegularExpression.escapedPattern(for: username))"
        return text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Telegram API Types

enum TelegramError: LocalizedError {
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .sendFailed(let detail): "Telegram send failed: \(detail)"
        }
    }
}

struct TelegramResponse<T: Decodable>: Decodable {
    let ok: Bool
    let result: T?
}

private struct TelegramUpdate: Decodable {
    let updateId: Int
    let message: TelegramMessage?

    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
    }
}

private struct TelegramMessage: Decodable {
    let messageId: Int
    let from: TelegramUser?
    let chat: TelegramChat
    let date: Int
    let text: String?
    let entities: [TelegramEntity]?
    let replyToMessage: TelegramReplyMessage?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from, chat, date, text, entities
        case replyToMessage = "reply_to_message"
    }
}

private struct TelegramReplyMessage: Decodable {
    let from: TelegramUser?
}

struct TelegramEntity: Decodable {
    let type: String
    let offset: Int
    let length: Int
}

struct TelegramUser: Decodable {
    let id: Int
    let firstName: String
    let lastName: String?
    let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case username
    }

    var displayName: String {
        if let lastName {
            return "\(firstName) \(lastName)"
        }
        return firstName
    }
}

private struct TelegramChat: Decodable {
    let id: Int64
    let title: String?
    let type: String
}
