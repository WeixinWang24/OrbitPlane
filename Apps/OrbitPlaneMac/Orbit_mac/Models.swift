import Foundation

enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let n = try? container.decode(Double.self) { self = .number(n) }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

struct OrbitSession: Codable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let backendName: String
    let systemPrompt: String?
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let metadata: [String: JSONValue]
}

struct OrbitMessage: Codable, Identifiable {
    var id: String { messageId }
    let messageId: String
    let sessionId: String
    let role: MessageRole
    let content: String
    let turnIndex: Int
    let createdAt: Date
    let metadata: [String: JSONValue]
}

struct ToolRequest: Codable {
    let toolCallId: String
    let toolName: String
    let arguments: [String: JSONValue]
    let providerItemId: String?
}

struct ExecutionPlan: Codable {
    let sourceBackend: String
    let planLabel: String
    let finalText: String?
    let model: String
    let metadata: [String: JSONValue]
    let toolRequests: [ToolRequest]
}

struct TurnResponse: Codable {
    let plan: ExecutionPlan
    let messages: [OrbitMessage]
}

struct HealthResponse: Codable {
    let ok: Bool
    let backend: String
    let runtimeRoot: String
    let dbPath: String
}
