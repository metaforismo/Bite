import Foundation
import SwiftData

@Model
final class CoachThread {
    @Attribute(.unique) var id: UUID
    var title: String
    var pinned: Bool
    var lastMessageAt: Date
    var createdAt: Date
    var firebaseUID: String?

    @Relationship(deleteRule: .cascade, inverse: \CoachMessage.thread)
    var messages: [CoachMessage] = []

    init(
        id: UUID = UUID(),
        title: String = "New chat",
        pinned: Bool = false,
        lastMessageAt: Date = Date(),
        createdAt: Date = Date(),
        firebaseUID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.pinned = pinned
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.firebaseUID = firebaseUID
    }
}
