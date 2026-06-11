import ActivityKit
import Foundation

/// Attributes for the workout Live Activity (lock screen + Dynamic Island).
/// Compiled into both the app and the BiteWidgets extension — same mechanism
/// as `BiteWidgetSnapshot` (extra target membership via the project's
/// synchronized-group exception set).
nonisolated struct WorkoutActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// Sets checked off so far.
        var completedSets: Int
        /// Total planned sets in the session.
        var totalSets: Int
        /// Exercise the user just completed a set for, if any.
        var currentExercise: String?
        /// When the active rest timer ends; nil when not resting.
        var restEndsAt: Date?
    }

    /// Wall-clock start of the session — drives the elapsed timer.
    var startedAt: Date
    /// Workout title, e.g. "Push Day".
    var workoutName: String
}
