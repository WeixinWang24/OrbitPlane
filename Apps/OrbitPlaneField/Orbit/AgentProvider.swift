import Foundation

protocol AgentProvider: Sendable {
    var backendName: String { get }

    func plan(
        from request: TurnRequest,
        onPartialText: (@Sendable (String) -> Void)?
    ) async -> ProviderPlan
}

struct ProviderSettings: Sendable {
    var model: String
    var baseURL: URL
    var apiKey: String?
    var basicAuthUsername: String?
    var basicAuthPassword: String?
    var maxTokens: Int

    static func resolve() -> ProviderSettings {
        let model = env("ORBIT2_PROVIDER_MODEL") ?? "gpt-4o"
        let rawURL = env("ORBIT2_VLLM_BASE_URL") ?? "http://localhost:8000/v1"
        let normalized = ProviderSettings.normalizeBaseURL(rawURL)
        let baseURL = URL(string: normalized) ?? URL(string: "http://localhost:8000/v1")!

        return ProviderSettings(
            model: model,
            baseURL: baseURL,
            apiKey: env("ORBIT2_VLLM_API_KEY"),
            basicAuthUsername: env("ORBIT2_VLLM_USERNAME"),
            basicAuthPassword: env("ORBIT2_VLLM_PASSWORD"),
            maxTokens: 1024
        )
    }

    static func normalizeBaseURL(_ raw: String) -> String {
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

    private static func env(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
