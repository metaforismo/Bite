import Foundation
import SwiftData

@Model
final class CoachPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var goal: String
    var weeks: Int
    var payloadJSON: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        goal: String,
        weeks: Int,
        payloadJSON: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.weeks = weeks
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
    }
}
