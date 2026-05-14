import Foundation

struct BridgeMessage: Identifiable, Sendable {
    let id: String
    let chatId: String
    let senderId: String
    let senderName: String
    let text: String
    let date: Date
}

protocol MessagingBridge: AnyObject, Sendable {
    var isRunning: Bool { get }
    func start() async
    func stop()
    func send(text: String, to chatId: String) async throws
    func messages() -> AsyncStream<BridgeMessage>
}
