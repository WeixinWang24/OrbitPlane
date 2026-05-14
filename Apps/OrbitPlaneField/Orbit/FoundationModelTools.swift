import Foundation
import FoundationModels
import UIKit

struct GetCurrentDateTimeTool: Tool {
    let name = "getCurrentDateTime"
    let description = "Get current date and time"

    @Generable
    struct Arguments {
        @Guide(description: "Format: short, medium, or full")
        var format: String
    }

    func call(arguments: Arguments) async throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        switch arguments.format.lowercased() {
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
        let tz = TimeZone.current.identifier
        return "\(formatter.string(from: Date())) (\(tz))"
    }
}

struct CalculateTool: Tool {
    let name = "calculate"
    let description = "Perform arithmetic on two numbers"

    @Generable
    struct Arguments {
        @Guide(description: "First number")
        var a: Double
        @Guide(description: "add, subtract, multiply, divide, or power")
        var operation: String
        @Guide(description: "Second number")
        var b: Double
    }

    func call(arguments: Arguments) async throws -> String {
        let result: Double
        switch arguments.operation.lowercased() {
        case "add", "+":
            result = arguments.a + arguments.b
        case "subtract", "-":
            result = arguments.a - arguments.b
        case "multiply", "*":
            result = arguments.a * arguments.b
        case "divide", "/":
            guard arguments.b != 0 else { return "Error: division by zero" }
            result = arguments.a / arguments.b
        case "power", "^", "**":
            result = pow(arguments.a, arguments.b)
        default:
            return "Unknown operation: \(arguments.operation)"
        }
        if result == result.rounded() && abs(result) < 1e15 {
            return String(format: "%.0f", result)
        }
        return String(result)
    }
}

struct SendTelegramMessageTool: Tool {
    let name = "sendTelegramMessage"
    let description = "Send a message to the Telegram group chat to communicate with other agents or users"

    let bridge: TelegramBridge
    let chatId: String

    @Generable
    struct Arguments {
        @Guide(description: "The message text to send to the Telegram group")
        var message: String
    }

    func call(arguments: Arguments) async throws -> String {
        do {
            try await bridge.send(text: arguments.message, to: chatId)
            return "Message sent to Telegram group."
        } catch {
            return "Failed to send: \(error.localizedDescription)"
        }
    }
}

struct GetDeviceInfoTool: Tool {
    let name = "getDeviceInfo"
    let description = "Get device name, OS version, or battery level"

    @Generable
    struct Arguments {
        @Guide(description: "Info: device, os, battery, or all")
        var infoType: String
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let device = UIDevice.current
        switch arguments.infoType.lowercased() {
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
}
