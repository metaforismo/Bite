import Foundation

/// Lightweight value passed from a `WorkoutCard` "Start" tap to the
/// `WorkoutSessionView` full-screen cover. Carries the originating artifact's
/// id (so completion can bump its version) and the decoded exercise list so
/// the session view doesn't have to re-decode the JSON payload.
struct WorkoutSessionContext: Identifiable, Hashable, Sendable {
    var id: UUID
    var artifactID: UUID?
    var title: String
    var exercises: [Exercise]

    struct Exercise: Identifiable, Hashable, Sendable {
        var id: UUID
        var name: String
        var muscleGroup: String?
        var sets: Int
        var reps: String?
        var restSec: Int
    }
}
