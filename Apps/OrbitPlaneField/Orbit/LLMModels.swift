import Foundation

enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

struct ProviderMessage: Sendable {
    var role: String
    var content: String?
    var toolCalls: [ToolCall]?
    var toolCallID: String?
}

struct ToolCall: Sendable {
    var id: String
    var functionName: String
    var arguments: [String: JSONValue]
}

struct ToolDefinition: Sendable {
    var name: String
    var description: String
    var parameters: [String: JSONValue]
}

struct TurnRequest: Sendable {
    var system: String?
    var messages: [ProviderMessage]
    var toolDefinitions: [ToolDefinition]?
}

struct ToolRequest: Sendable {
    var toolCallID: String
    var toolName: String
    var arguments: [String: JSONValue]
}

struct ProviderPlan: Sendable {
    var sourceBackend: String
    var label: String
    var finalText: String?
    var model: String
    var toolRequests: [ToolRequest]
    var metadata: [String: JSONValue]
}
