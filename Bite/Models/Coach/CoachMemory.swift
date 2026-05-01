import Foundation
import SwiftData

@Model
final class CoachMemory {
    @Attribute(.unique) var id: UUID
    var category: String          // "Goals" | "Nutrition" | "Exercise Preferences" | "Barriers" | "Dislikes" | ...
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var firebaseUID: String?

    init(
        id: UUID = UUID(),
        category: String,
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        firebaseUID: String? = nil
    ) {
        self.id = id
        self.category = category
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.firebaseUID = firebaseUID
    }
}
