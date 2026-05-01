import Foundation
import SwiftData

@Model
final class CheckInSchedule {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var cadence: String         // e.g. "daily@08:00", "weekly:monday@09:00"
    var nextFireAt: Date
    var alarmIdRaw: String?     // AlarmKit alarm id (UUID string) once scheduled
    var createdAt: Date

    init(
        id: UUID = UUID(),
        prompt: String,
        cadence: String,
        nextFireAt: Date,
        alarmIdRaw: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.cadence = cadence
        self.nextFireAt = nextFireAt
        self.alarmIdRaw = alarmIdRaw
        self.createdAt = createdAt
    }
}
