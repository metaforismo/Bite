import ActivityKit
import Foundation

/// Manages the workout Live Activity lifecycle from the app side.
///
/// ActivityKit etiquette baked in:
/// - updates are equality-skipped and throttled to ≥15s apart unless the
///   content state actually changed,
/// - every push carries a `staleDate` 30 minutes out so an abandoned
///   activity dims instead of lying,
/// - `start` adopts an orphaned activity left over from a previous launch
///   (app killed mid-workout) instead of stacking a second one,
/// - `end` tears down every activity of this type immediately.
@MainActor
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()
    private init() {}

    private var activity: Activity<WorkoutActivityAttributes>?
    private var lastPushedState: WorkoutActivityAttributes.ContentState?
    private var lastPushAt: Date = .distantPast

    private static let minPushInterval: TimeInterval = 15
    private static let staleInterval: TimeInterval = 30 * 60

    // MARK: - Lifecycle

    /// Starts (or adopts) the Live Activity for an in-progress session.
    func start(session: SDStrengthSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Adopt an orphan from a previous launch rather than stacking a new one.
        if activity == nil {
            activity = Activity<WorkoutActivityAttributes>.activities.first
        }

        let state = WorkoutActivityAttributes.ContentState(
            completedSets: session.sets.filter { $0.completedAt != nil }.count,
            totalSets: session.sets.count,
            currentExercise: nil,
            restEndsAt: nil
        )

        if activity != nil {
            // Re-sync the adopted activity with the live session state.
            push(state)
            return
        }

        do {
            let attributes = WorkoutActivityAttributes(
                startedAt: session.startedAt,
                workoutName: session.title
            )
            let content = ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(Self.staleInterval)
            )
            activity = try Activity.request(attributes: attributes, content: content)
            lastPushedState = state
            lastPushAt = Date()
        } catch {
            // Best-effort — the workout works fine without a Live Activity.
        }
    }

    /// Pushes new progress. Identical states inside the throttle window are
    /// dropped; changed states go out immediately.
    func update(completedSets: Int, totalSets: Int, currentExercise: String?, restEndsAt: Date?) {
        guard activity != nil else { return }

        let state = WorkoutActivityAttributes.ContentState(
            completedSets: completedSets,
            totalSets: totalSets,
            currentExercise: currentExercise,
            restEndsAt: restEndsAt
        )
        if state == lastPushedState,
           Date().timeIntervalSince(lastPushAt) < Self.minPushInterval {
            return
        }
        push(state)
    }

    /// Ends the tracked activity plus any orphans, removing them immediately.
    func end() {
        activity = nil
        lastPushedState = nil
        lastPushAt = .distantPast

        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                let content = ActivityContent(state: activity.content.state, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Private

    private func push(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        lastPushedState = state
        lastPushAt = Date()
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(Self.staleInterval)
        )
        // `Activity` isn't Sendable — re-fetch it by id inside the task
        // instead of capturing it across the isolation boundary.
        let id = activity.id
        Task {
            for live in Activity<WorkoutActivityAttributes>.activities where live.id == id {
                await live.update(content)
            }
        }
    }
}
