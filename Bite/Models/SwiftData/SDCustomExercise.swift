import Foundation
import SwiftData

@Model
final class SDCustomExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String        // Chest / Back / Legs / Core / Cardio / Other
    var defaultRestSec: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String = "Other",
        defaultRestSec: Int = 60
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.defaultRestSec = defaultRestSec
        self.createdAt = Date()
    }
}
