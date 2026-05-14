import Foundation

struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
