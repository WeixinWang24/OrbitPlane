import Foundation
import FoundationModels

final class FoundationModelsProvider: AgentProvider, @unchecked Sendable {
    let backendName = "apple-on-device"

    private var baseInstructions: String?
    private var processedTurnCount = 0

    // Clean text history — no tool call artifacts
    private var history: [(role: String, content: String)] = []
    private var compactedSummary: String?
    private var cachedContextSize: Int?
    private var compactionCount = 0

    private var bridgeContext: ToolRouter.BridgeContext?

    private let compactionThreshold = 0.45
    private let overheadMultiplier = 1.5
    private let maxRecentTurns = 6

    func setBridge(_ bridge: TelegramBridge?, chatId: String?) {
        if let bridge, let chatId, !chatId.isEmpty {
            bridgeContext = ToolRouter.BridgeContext(bridge: bridge, chatId: chatId)
        } else {
            bridgeContext = nil
        }
    }

    func plan(
        from request: TurnRequest,
        onPartialText: (@Sendable (String) -> Void)? = nil
    ) async -> ProviderPlan {
        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            return errorPlan(unavailabilityMessage(model.availability))
        }

        let instructions = request.system ?? "You are a helpful assistant."
        let contextSize = resolveContextSize()

        let conversationReset = request.messages.count < processedTurnCount
        let instructionsChanged = baseInstructions != instructions

        if conversationReset || instructionsChanged {
            resetState(instructions: instructions)
        }

        guard let lastUserMessage = request.messages.last(where: { $0.role == "user" }),
              let content = lastUserMessage.content, !content.isEmpty else {
            return errorPlan("No user message found")
        }

        baseInstructions = instructions

        // Progressive disclosure: select tools based on user intent
        let routing = await ToolRouter.classifyIntent(for: content, bridgeContext: bridgeContext)
        let neededTools = routing.tools

        // Pre-flight token budget check
        let toolOverhead = neededTools.count * 80
        let fullInstructions = buildFullInstructions(instructions)
        let projectedUsage = estimateProjectedUsage(
            instructions: fullInstructions,
            pendingMessage: content,
            toolOverhead: toolOverhead
        )

        if projectedUsage > Int(Double(contextSize) * compactionThreshold)
            && !history.isEmpty {
            await performCompaction(baseInstructions: instructions)
        }

        // Fresh session per turn — tool call results stay ephemeral
        let session = LanguageModelSession(
            tools: neededTools,
            instructions: buildFullInstructions(instructions)
        )

        do {
            let response = try await session.respond(to: content)
            processedTurnCount = request.messages.count

            appendToHistory(user: content, assistant: response.content)

            return buildSuccessPlan(
                text: response.content,
                routing: routing,
                tools: neededTools,
                contextSize: contextSize,
                toolOverhead: toolOverhead
            )
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                return await retryAfterCompaction(
                    content: content,
                    instructions: instructions,
                    routing: routing,
                    tools: neededTools
                )
            }
            return errorPlan(generationErrorMessage(error))
        } catch {
            return errorPlan("Generation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Retry After Compaction

    private func retryAfterCompaction(
        content: String,
        instructions: String,
        routing: ToolRoutingResult,
        tools: [any Tool]
    ) async -> ProviderPlan {
        await performCompaction(baseInstructions: instructions)

        let retrySession = LanguageModelSession(
            tools: tools,
            instructions: buildFullInstructions(instructions)
        )

        do {
            let response = try await retrySession.respond(to: content)
            processedTurnCount += 1

            appendToHistory(user: content, assistant: response.content)

            return ProviderPlan(
                sourceBackend: backendName,
                label: "on-device-response",
                finalText: response.content.isEmpty ? nil : response.content,
                model: "apple-intelligence",
                toolRequests: [],
                metadata: [
                    "context_compacted": .bool(true),
                    "compaction_count": .number(Double(compactionCount)),
                    "routing_method": .string(routing.method)
                ]
            )
        } catch {
            return errorPlan(
                "Generation failed after compaction: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - History Management

    private func appendToHistory(user: String, assistant: String) {
        history.append((role: "user", content: user))
        history.append((role: "assistant", content: assistant))

        if history.count > maxRecentTurns {
            history = Array(history.suffix(maxRecentTurns))
        }
    }

    // MARK: - Token Estimation

    private func estimateProjectedUsage(
        instructions: String,
        pendingMessage: String,
        toolOverhead: Int
    ) -> Int {
        let instructionTokens = TokenEstimator.estimate(instructions) + 4
        let messageTokens = TokenEstimator.estimate(pendingMessage) + 4
        let responseReserve = 400
        return Int(Double(instructionTokens) * overheadMultiplier)
            + messageTokens + responseReserve + toolOverhead
    }

    // MARK: - Compaction

    private func performCompaction(baseInstructions: String) async {
        guard !history.isEmpty else { return }

        var textToSummarize = ""
        if let existing = compactedSummary {
            textToSummarize += "Previous context: \(existing)\n\n"
        }
        for (role, content) in history {
            let label = role == "user" ? "User" : "Assistant"
            textToSummarize += "\(label): \(content)\n"
        }

        let maxChars = 1800
        if textToSummarize.count > maxChars {
            textToSummarize = String(textToSummarize.suffix(maxChars))
        }

        let summaryInstructions =
            "Summarize this conversation concisely. Preserve key facts and decisions. " +
            "Respond with ONLY the summary, no preamble."

        let summarySession = LanguageModelSession(instructions: summaryInstructions)

        do {
            let response = try await summarySession.respond(to: textToSummarize)
            let summary = response.content
            if !summary.isEmpty && summary.count < textToSummarize.count {
                compactedSummary = summary
            } else {
                applyFallbackCompaction()
            }
        } catch {
            applyFallbackCompaction()
        }

        history.removeAll()
        compactionCount += 1
        processedTurnCount = 0
    }

    private func applyFallbackCompaction() {
        let recentCount = min(4, history.count)
        let dropCount = history.count - recentCount

        if dropCount > 0 {
            let dropped = history.prefix(dropCount)
            let summary = dropped
                .map { "\($0.role == "user" ? "U" : "A"): \($0.content)" }
                .joined(separator: " | ")
            let existing = compactedSummary.map { $0 + " | " } ?? ""
            compactedSummary = String((existing + summary).prefix(800))
            history = Array(history.suffix(recentCount))
        } else {
            let all = history
                .map { "\($0.role == "user" ? "U" : "A"): \($0.content)" }
                .joined(separator: " | ")
            let existing = compactedSummary.map { $0 + " | " } ?? ""
            compactedSummary = String((existing + all).prefix(800))
        }
    }

    // MARK: - Instructions Builder

    private func buildFullInstructions(_ base: String) -> String {
        var parts = [base]

        if let summary = compactedSummary {
            parts.append("Earlier context:\n\(summary)")
        }

        if !history.isEmpty {
            let recent = history.suffix(maxRecentTurns).map { entry in
                let label = entry.role == "user" ? "User" : "Assistant"
                return "\(label): \(entry.content)"
            }.joined(separator: "\n")
            parts.append("Recent conversation:\n\(recent)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Response Builder

    private func buildSuccessPlan(
        text: String,
        routing: ToolRoutingResult,
        tools: [any Tool],
        contextSize: Int,
        toolOverhead: Int
    ) -> ProviderPlan {
        var metadata: [String: JSONValue] = [:]

        let postInstructions = buildFullInstructions(baseInstructions ?? "")
        let postUsage = Int(Double(TokenEstimator.estimate(postInstructions) + 4) * overheadMultiplier) + toolOverhead
        metadata["tokens_estimated"] = .number(Double(postUsage))
        metadata["context_size"] = .number(Double(contextSize))
        metadata["utilization"] = .string(
            String(format: "%.0f%%", Double(postUsage) / Double(contextSize) * 100)
        )
        metadata["routing_method"] = .string(routing.method)

        if !tools.isEmpty {
            let names = tools.map(\.name).joined(separator: ", ")
            metadata["active_tools"] = .string(names)
        }

        if compactedSummary != nil {
            metadata["has_compacted_context"] = .bool(true)
            metadata["compaction_count"] = .number(Double(compactionCount))
        }

        return ProviderPlan(
            sourceBackend: backendName,
            label: "on-device-response",
            finalText: text.isEmpty ? nil : text,
            model: "apple-intelligence",
            toolRequests: [],
            metadata: metadata
        )
    }

    // MARK: - State Management

    private func resetState(instructions: String) {
        baseInstructions = instructions
        processedTurnCount = 0
        history.removeAll()
        compactedSummary = nil
        compactionCount = 0
    }

    private func resolveContextSize() -> Int {
        if let cached = cachedContextSize { return cached }
        let size = SystemLanguageModel.default.contextSize
        cachedContextSize = size
        return size
    }

    // MARK: - Error Messages

    private func unavailabilityMessage(
        _ availability: SystemLanguageModel.Availability
    ) -> String {
        switch availability {
        case .available:
            return "Model should be available"
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Please enable Apple Intelligence in Settings"
        case .unavailable(.modelNotReady):
            return "Model is downloading — try again shortly"
        case .unavailable:
            return "On-device model is unavailable"
        @unknown default:
            return "On-device model is unavailable"
        }
    }

    private func generationErrorMessage(
        _ error: LanguageModelSession.GenerationError
    ) -> String {
        switch error {
        case .exceededContextWindowSize:
            return "Message too long for on-device model — try a shorter message"
        case .guardrailViolation:
            return "Request was blocked by safety guardrails"
        case .rateLimited:
            return "On-device model is rate limited — try again shortly"
        case .unsupportedLanguageOrLocale:
            return "This language is not supported by the on-device model"
        case .assetsUnavailable:
            return "Model assets unavailable — Apple Intelligence may have been disabled"
        case .decodingFailure:
            return "Failed to decode model response"
        case .refusal:
            return "The model refused to respond to this request"
        case .concurrentRequests:
            return "Only one request at a time is supported"
        case .unsupportedGuide:
            return "Unsupported generation guide"
        @unknown default:
            return "Generation error: \(error.localizedDescription)"
        }
    }

    private func errorPlan(_ message: String) -> ProviderPlan {
        ProviderPlan(
            sourceBackend: backendName,
            label: "on-device-error",
            finalText: message,
            model: "apple-intelligence",
            toolRequests: [],
            metadata: [
                "error_type": .string("on_device_error"),
                "error": .string(message),
            ]
        )
    }
}
