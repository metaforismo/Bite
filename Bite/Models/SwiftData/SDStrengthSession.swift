import Foundation
import SwiftData

@Model
final class SDStrengthSession {
    @Attribute(.unique) var id: UUID
    var workoutArtifactID: UUID?  // links back to the originating WorkoutArtifactModel
    var title: String
    var startedAt: Date
    var completedAt: Date?
    @Relationship(deleteRule: .cascade) var sets: [SDStrengthSet]

    init(
        id: UUID = UUID(),
        workoutArtifactID: UUID? = nil,
        title: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        sets: [SDStrengthSet] = []
    ) {
        self.id = id
        self.workoutArtifactID = workoutArtifactID
        self.title = title
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.sets = sets
    }

    var elapsedSeconds: TimeInterval {
        (completedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

@Model
final class SDStrengthSet {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var setIndex: Int
    var weightLb: Double
    var reps: Int
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        setIndex: Int,
        weightLb: Double = 0,
        reps: Int = 0,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.weightLb = weightLb
        self.reps = reps
        self.completedAt = completedAt
    }
}
