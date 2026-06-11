import ActivityKit
import SwiftUI
import WidgetKit

/// Workout Live Activity: lock-screen banner + Dynamic Island.
struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.workoutName)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(WorkoutActivityStyle.accent)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsedTimer(context.attributes)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .frame(maxWidth: 60)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(context.state.completedSets)/\(context.state.totalSets) sets")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                            Spacer()
                            if let restEndsAt = context.state.restEndsAt, restEndsAt > Date() {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(timerInterval: Date()...restEndsAt, countsDown: true)
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .monospacedDigit()
                                        .frame(maxWidth: 50)
                                }
                                .foregroundStyle(WorkoutActivityStyle.accent)
                            } else if let exercise = context.state.currentExercise {
                                Text(exercise)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        ProgressView(
                            value: Double(context.state.completedSets),
                            total: Double(max(1, context.state.totalSets))
                        )
                        .tint(WorkoutActivityStyle.accent)
                    }
                }
            } compactLeading: {
                elapsedTimer(context.attributes)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(WorkoutActivityStyle.accent)
                    .frame(maxWidth: 44)
            } compactTrailing: {
                Text("\(context.state.completedSets)/\(context.state.totalSets)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(WorkoutActivityStyle.accent)
            }
            .keylineTint(WorkoutActivityStyle.accent)
        }
    }

    /// Elapsed-time timer anchored to the session start. The far end of the
    /// interval just needs to be comfortably beyond any real workout.
    private func elapsedTimer(_ attributes: WorkoutActivityAttributes) -> some View {
        Text(
            timerInterval: attributes.startedAt...attributes.startedAt.addingTimeInterval(8 * 60 * 60),
            countsDown: false
        )
        .monospacedDigit()
    }
}

/// Shared styling for the workout activity (widget target can't see the
/// app's design tokens; this mirrors `biteRed`).
enum WorkoutActivityStyle {
    static let accent = Color(red: 0.93, green: 0.26, blue: 0.26)
}

private struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(context.attributes.workoutName)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(WorkoutActivityStyle.accent)
                }
                Spacer()
                Text(
                    timerInterval: context.attributes.startedAt...context.attributes.startedAt.addingTimeInterval(8 * 60 * 60),
                    countsDown: false
                )
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: 64)
                .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("\(context.state.completedSets)/\(context.state.totalSets) sets")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Spacer()
                if let restEndsAt = context.state.restEndsAt, restEndsAt > Date() {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Rest")
                            .font(.system(size: 12, weight: .semibold))
                        Text(timerInterval: Date()...restEndsAt, countsDown: true)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: 50)
                    }
                    .foregroundStyle(WorkoutActivityStyle.accent)
                } else if let exercise = context.state.currentExercise {
                    Text(exercise)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            ProgressView(
                value: Double(context.state.completedSets),
                total: Double(max(1, context.state.totalSets))
            )
            .tint(WorkoutActivityStyle.accent)
        }
        .foregroundStyle(.white)
        .padding(14)
    }
}
