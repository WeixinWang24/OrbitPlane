import Foundation
import FoundationModels

@Generable(description: "Capabilities needed to answer a message")
struct ToolIntent {
    @Guide(description: "Needs current date or time")
    var dateTime: Bool
    @Guide(description: "Needs arithmetic")
    var calculator: Bool
    @Guide(description: "Needs device info")
    var device: Bool
    @Guide(description: "Needs to send a message to the Telegram group")
    var telegramSend: Bool
}

struct ToolRoutingResult {
    let tools: [any Tool]
    let method: String // "model" or "keyword"
}

struct ToolRouter {

    // MARK: - Model-Based Intent Classification

    struct BridgeContext {
        let bridge: TelegramBridge
        let chatId: String
    }

    static func classifyIntent(
        for message: String,
        bridgeContext: BridgeContext? = nil
    ) async -> ToolRoutingResult {
        guard SystemLanguageModel.default.isAvailable else {
            return ToolRoutingResult(tools: [], method: "unavailable")
        }

        let session = LanguageModelSession(
            instructions: "Classify what capabilities are needed to answer this message."
        )

        do {
            let result = try await session.respond(
                to: message,
                generating: ToolIntent.self
            )
            return ToolRoutingResult(
                tools: buildTools(from: result.content, bridgeContext: bridgeContext),
                method: "model"
            )
        } catch {
            return ToolRoutingResult(tools: [], method: "model-error")
        }
    }

    private static func buildTools(
        from intent: ToolIntent,
        bridgeContext: BridgeContext?
    ) -> [any Tool] {
        var tools: [any Tool] = []
        if intent.dateTime { tools.append(GetCurrentDateTimeTool()) }
        if intent.calculator { tools.append(CalculateTool()) }
        if intent.device { tools.append(GetDeviceInfoTool()) }
        if intent.telegramSend, let ctx = bridgeContext {
            tools.append(SendTelegramMessageTool(bridge: ctx.bridge, chatId: ctx.chatId))
        }
        return tools
    }

    // MARK: - Keyword Fallback

    static func selectToolsByKeyword(for message: String) -> [any Tool] {
        let text = message.lowercased()
        var tools: [any Tool] = []

        if needsDateTime(text) { tools.append(GetCurrentDateTimeTool()) }
        if needsCalculator(text) { tools.append(CalculateTool()) }
        if needsDeviceInfo(text) { tools.append(GetDeviceInfoTool()) }

        return tools
    }

    // MARK: - Helpers

    static func signature(_ tools: [any Tool]) -> Set<String> {
        Set(tools.map(\.name))
    }

    private static func needsDateTime(_ text: String) -> Bool {
        let kw = [
            "what time", "current time", "right now", "today's date", "what day",
            "几点", "时间", "日期", "今天", "现在几", "当前时间", "星期几"
        ]
        return kw.contains { text.contains($0) }
    }

    private static func needsCalculator(_ text: String) -> Bool {
        let kw = ["calculate", "compute", "计算", "算一下", "等于多少", "等于几"]
        if kw.contains(where: { text.contains($0) }) { return true }
        return text.range(of: "\\d\\s*[+\\-*/×÷^]\\s*\\d", options: .regularExpression) != nil
    }

    private static func needsDeviceInfo(_ text: String) -> Bool {
        let kw = [
            "device", "battery", "phone model", "ios version", "system info",
            "设备", "电量", "电池", "手机型号", "系统版本", "什么型号"
        ]
        return kw.contains { text.contains($0) }
    }
}
