import Foundation

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isStreaming = false
    var telegramConnected = false

    private var provider: any AgentProvider
    let systemPrompt: String
    private let sessionManager: ChatSessionManager?

    private var bridge: TelegramBridge?
    private var bridgeChatId: String?
    private var listeningTask: Task<Void, Never>?

    private let maxToolRounds = 5

    init(provider: any AgentProvider = OpenAICompatibleProvider(settings: .resolve()),
         systemPrompt: String = "You are Orbit, a helpful AI assistant with a cyberpunk personality. Be concise and direct.",
         sessionManager: ChatSessionManager? = nil) {
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.sessionManager = sessionManager

        if let manager = sessionManager {
            self.messages = manager.loadCurrentMessages()
        }
    }

    func updateProvider(_ provider: any AgentProvider) {
        self.provider = provider
        syncBridgeToProvider()
    }

    // MARK: - Telegram Bridge

    func connectBridge(_ newBridge: TelegramBridge, chatId: String) {
        disconnectBridge()
        bridge = newBridge
        bridgeChatId = chatId
        telegramConnected = true
        syncBridgeToProvider()

        listeningTask = Task { [weak self] in
            guard let self, let bridge = self.bridge else { return }
            await bridge.start()

            for await incoming in bridge.messages() {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.handleIncomingBridgeMessage(incoming)
                }
            }
        }
    }

    func disconnectBridge() {
        listeningTask?.cancel()
        listeningTask = nil
        bridge?.stop()
        bridge = nil
        bridgeChatId = nil
        telegramConnected = false
        syncBridgeToProvider()
    }

    private func syncBridgeToProvider() {
        if let fmp = provider as? FoundationModelsProvider {
            fmp.setBridge(bridge, chatId: bridgeChatId)
        }
    }

    private func handleIncomingBridgeMessage(_ msg: BridgeMessage) {
        let displayText = "[\(msg.senderName)] \(msg.text)"
        messages.append(ChatMessage(role: .user, content: displayText))
        sessionManager?.saveCurrentMessages(messages)

        Task {
            await processAndRespond(to: msg.text, replyToChatId: msg.chatId)
        }
    }

    // MARK: - Send

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        messages.append(ChatMessage(role: .assistant, content: ""))
        isStreaming = true

        Task {
            await processAndRespond(to: text, replyToChatId: nil)
        }
    }

    private func processAndRespond(to text: String, replyToChatId: String?) async {
        let needsPlaceholder = messages.last?.role != .assistant || !(messages.last?.content.isEmpty ?? true)

        await MainActor.run {
            if needsPlaceholder {
                messages.append(ChatMessage(role: .assistant, content: ""))
                isStreaming = true
            }
        }

        let isFoundationModel = provider is FoundationModelsProvider
        let toolRegistry = isFoundationModel ? nil : OpenAIToolRegistry(bridge: bridge, chatId: bridgeChatId)

        var providerMessages = await MainActor.run {
            messages.dropLast().map { msg in
                ProviderMessage(
                    role: msg.role == .user ? "user" : "assistant",
                    content: msg.content
                )
            }
        }

        var finalText: String?

        for _ in 0..<maxToolRounds {
            let request = TurnRequest(
                system: systemPrompt,
                messages: Array(providerMessages),
                toolDefinitions: toolRegistry?.definitions
            )

            let plan = await provider.plan(from: request, onPartialText: nil)

            if plan.toolRequests.isEmpty {
                finalText = plan.finalText
                break
            }

            // Model requested tool calls — execute and feed results back
            guard let registry = toolRegistry else {
                finalText = plan.finalText
                break
            }

            if let text = plan.finalText, !text.isEmpty {
                providerMessages.append(ProviderMessage(
                    role: "assistant",
                    content: text
                ))
            }

            var toolCalls: [ToolCall] = []
            for req in plan.toolRequests {
                toolCalls.append(ToolCall(
                    id: req.toolCallID,
                    functionName: req.toolName,
                    arguments: req.arguments
                ))
            }
            providerMessages.append(ProviderMessage(
                role: "assistant",
                content: nil,
                toolCalls: toolCalls
            ))

            for req in plan.toolRequests {
                let result = await registry.execute(req)
                providerMessages.append(ProviderMessage(
                    role: "tool",
                    content: result,
                    toolCallID: req.toolCallID
                ))
            }
        }

        let responseText = finalText ?? "No response received."

        await MainActor.run {
            if let lastIndex = messages.indices.last {
                messages[lastIndex].content = responseText
            }
            isStreaming = false
            sessionManager?.saveCurrentMessages(messages)
        }

        if let chatId = replyToChatId, let bridge {
            try? await bridge.send(text: responseText, to: chatId)
        }
    }

    // MARK: - Session Management

    func switchSession(to id: UUID) {
        sessionManager?.saveCurrentMessages(messages)
        sessionManager?.switchSession(id)
        messages = sessionManager?.loadCurrentMessages() ?? []
        inputText = ""
    }

    func createNewSession() {
        sessionManager?.saveCurrentMessages(messages)
        sessionManager?.createSession()
        messages = []
        inputText = ""
    }

    func deleteSession(_ id: UUID) {
        let wasCurrent = sessionManager?.currentSessionId == id
        sessionManager?.deleteSession(id)
        if wasCurrent {
            messages = sessionManager?.loadCurrentMessages() ?? []
            inputText = ""
        }
    }

    func clearHistory() {
        messages.removeAll()
        sessionManager?.saveCurrentMessages([])
    }
}
