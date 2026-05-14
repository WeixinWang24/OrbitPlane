import Foundation
import UIKit

struct OpenAIToolRegistry {
    private let bridge: TelegramBridge?
    private let chatId: String?

    init(bridge: TelegramBridge? = nil, chatId: String? = nil) {
        self.bridge = bridge
        self.chatId = chatId
    }

    // MARK: - Tool Definitions

    var definitions: [ToolDefinition] {
        var defs = [
            ToolDefinition(
                name: "getCurrentDateTime",
                description: "Get current date and time",
                parameters: [
                    "type": .string("object"),
                    "properties": .object([
                        "format": .object([
                            "type": .string("string"),
                            "description": .string("Format: short, medium, or full")
                        ])
                    ]),
                    "required": .array([.string("format")])
                ]
            ),
            ToolDefinition(
                name: "calculate",
                description: "Perform arithmetic on two numbers",
                parameters: [
                    "type": .string("object"),
                    "properties": .object([
                        "a": .object([
                            "type": .string("number"),
                            "description": .string("First number")
                        ]),
                        "operation": .object([
                            "type": .string("string"),
                            "description": .string("add, subtract, multiply, divide, or power")
                        ]),
                        "b": .object([
                            "type": .string("number"),
                            "description": .string("Second number")
                        ])
                    ]),
                    "required": .array([.string("a"), .string("operation"), .string("b")])
                ]
            ),
            ToolDefinition(
                name: "getDeviceInfo",
                description: "Get device name, OS version, or battery level",
                parameters: [
                    "type": .string("object"),
                    "properties": .object([
                        "infoType": .object([
                            "type": .string("string"),
                            "description": .string("Info: device, os, battery, or all")
                        ])
                    ]),
                    "required": .array([.string("infoType")])
                ]
            )
        ]

        if bridge != nil && chatId != nil {
            defs.append(ToolDefinition(
                name: "sendTelegramMessage",
                description: "Send a message to the Telegram group chat to communicate with other agents or users",
                parameters: [
                    "type": .string("object"),
                    "properties": .object([
                        "message": .object([
                            "type": .string("string"),
                            "description": .string("The message text to send to the Telegram group")
                        ])
                    ]),
                    "required": .array([.string("message")])
                ]
            ))
        }

        return defs
    }

    // MARK: - Tool Execution

    func execute(_ request: ToolRequest) async -> String {
        switch request.toolName {
        case "getCurrentDateTime":
            return executeDateTime(request.arguments)
        case "calculate":
            return executeCalculate(request.arguments)
        case "getDeviceInfo":
            return await MainActor.run { executeDeviceInfo(request.arguments) }
        case "sendTelegramMessage":
            return await executeTelegramSend(request.arguments)
        default:
            return "Unknown tool: \(request.toolName)"
        }
    }

    // MARK: - Tool Implementations

    private func executeDateTime(_ args: [String: JSONValue]) -> String {
        let format: String
        if case .string(let f) = args["format"] {
            format = f
        } else {
            format = "medium"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        switch format.lowercased() {
        case "short":
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        case "full":
            formatter.dateStyle = .full
            formatter.timeStyle = .full
        default:
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
        }
        return "\(formatter.string(from: Date())) (\(TimeZone.current.identifier))"
    }

    private func executeCalculate(_ args: [String: JSONValue]) -> String {
        guard case .number(let a) = args["a"],
              case .number(let b) = args["b"],
              case .string(let op) = args["operation"] else {
            return "Invalid arguments"
        }

        let result: Double
        switch op.lowercased() {
        case "add", "+": result = a + b
        case "subtract", "-": result = a - b
        case "multiply", "*": result = a * b
        case "divide", "/":
            guard b != 0 else { return "Error: division by zero" }
            result = a / b
        case "power", "^", "**": result = pow(a, b)
        default: return "Unknown operation: \(op)"
        }

        if result == result.rounded() && abs(result) < 1e15 {
            return String(format: "%.0f", result)
        }
        return String(result)
    }

    @MainActor
    private func executeDeviceInfo(_ args: [String: JSONValue]) -> String {
        let infoType: String
        if case .string(let t) = args["infoType"] {
            infoType = t
        } else {
            infoType = "all"
        }

        let device = UIDevice.current
        switch infoType.lowercased() {
        case "device":
            return "\(device.name), \(device.model)"
        case "os":
            return "\(device.systemName) \(device.systemVersion)"
        case "battery":
            device.isBatteryMonitoringEnabled = true
            let level = device.batteryLevel
            let pct = level >= 0 ? "\(Int(level * 100))%" : "unknown"
            return "Battery: \(pct)"
        default:
            device.isBatteryMonitoringEnabled = true
            let level = device.batteryLevel
            let pct = level >= 0 ? "\(Int(level * 100))%" : "unknown"
            return "\(device.name), \(device.systemName) \(device.systemVersion), Battery: \(pct)"
        }
    }

    private func executeTelegramSend(_ args: [String: JSONValue]) async -> String {
        guard let bridge, let chatId else {
            return "Telegram bridge not connected"
        }
        guard case .string(let message) = args["message"] else {
            return "Missing message argument"
        }
        do {
            try await bridge.send(text: message, to: chatId)
            return "Message sent to Telegram group."
        } catch {
            return "Failed to send: \(error.localizedDescription)"
        }
    }
}
