import Foundation
import SwiftData

@Model
final class WorkoutArtifactModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var scheduledAt: Date?
    var completedAt: Date?
    var planId: UUID?
    var payloadJSON: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        scheduledAt: Date? = nil,
        completedAt: Date? = nil,
        planId: UUID? = nil,
        payloadJSON: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.scheduledAt = scheduledAt
        self.completedAt = completedAt
        self.planId = planId
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
    }
}
