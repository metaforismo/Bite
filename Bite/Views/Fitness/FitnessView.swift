import SwiftUI
import SwiftData

struct FitnessView: View {
    @Bindable var router: BiteRouter
    @Query(sort: [SortDescriptor(\WorkoutArtifactModel.scheduledAt, order: .forward)])
    private var workouts: [WorkoutArtifactModel]

    @Query(sort: [SortDescriptor(\SDStrengthSession.startedAt, order: .reverse)])
    private var sessions: [SDStrengthSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BiteTopBar(onBack: nil) { EmptyView() }
                Group {
                    header
                    readinessPanel
                    if !sessions.isEmpty {
                        densityStrip
                    }
                    if workouts.isEmpty {
                        emptyState
                    } else {
                        workoutList
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, BiteTheme.deviceSafeAreaTop)
            .padding(.bottom, BiteTheme.bottomFloatingClearance + 56)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
    }

    /// Last-7-day weekly volume bar + session count callout. Sits above
    /// the workout list when there's any session history.
    private var densityStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let recent = sessions.filter { $0.startedAt >= weekStart }
        let dailyVolume: [Double] = (0..<7).map { offset -> Double in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { return 0 }
            let dayStart = cal.startOfDay(for: day)
            let next = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            return recent
                .filter { $0.startedAt >= dayStart && $0.startedAt < next }
                .reduce(0.0) { acc, session in
                    acc + session.sets.reduce(0.0) { setAcc, s in
                        setAcc + (s.weightLb * Double(s.reps))
                    }
                }
        }
        let totalVolume = dailyVolume.reduce(0, +)
        let maxBar = max(1, dailyVolume.max() ?? 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(.biteInkFaint)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(totalVolume))")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.biteInk)
                            .monospacedDigit()
                        Text("lb lifted")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.biteInkMuted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SESSIONS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(.biteInkFaint)
                    Text("\(recent.count)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.biteRed)
                        .monospacedDigit()
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let v = dailyVolume[i]
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(v > 0 ? Color.biteRed : Color.biteRed.opacity(0.10))
                            .frame(height: max(4, CGFloat(v / maxBar) * 64))
                        Text(dayLabel(for: i, weekStart: weekStart))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.biteInkFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
        .biteShadow(.raised)
        .askCoachContext("How's my training volume trending this week?")
    }

    private func dayLabel(for offset: Int, weekStart: Date) -> String {
        let cal = Calendar.current
        guard let date = cal.date(byAdding: .day, value: offset, to: weekStart) else { return "" }
        let weekday = cal.component(.weekday, from: date)
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        return labels[weekday - 1]
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Fitness")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(.biteInk)
            Text("Workouts and plans Bite has built for you")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.biteInkMuted)
        }
    }

    private var readinessPanel: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let recent = sessions.filter { $0.startedAt >= weekStart }
        let completedSets = recent.reduce(0) { partial, session in
            partial + session.sets.filter { $0.completedAt != nil }.count
        }
        let totalVolume = recent.reduce(0.0) { acc, session in
            acc + session.sets.reduce(0.0) { $0 + ($1.weightLb * Double($1.reps)) }
        }
        let readiness = sessions.isEmpty ? nil : min(96, 58 + completedSets * 3)
        let recommendation = sessions.isEmpty ? "Build a baseline" : (completedSets >= 18 ? "Bias recovery today" : "Strength window open")

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRAINING READINESS")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(.biteInkFaint)
                    Text(recommendation)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.biteInk)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(readiness.map { "\($0)" } ?? "--")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(readiness == nil ? .biteInkFaint : .biteRingRecovery)
                        .monospacedDigit()
                    Text("score")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.biteInkFaint)
                }
            }

            HStack(spacing: 10) {
                FitnessSignalTile(title: "Load", value: "\(completedSets)", unit: "sets", tint: .biteRed)
                FitnessSignalTile(title: "Volume", value: "\(Int(totalVolume))", unit: "lb", tint: .biteInk)
                FitnessSignalTile(title: "Target", value: sessions.isEmpty ? "Base" : (completedSets >= 18 ? "Low" : "Mod"), unit: "strain", tint: .biteCarbs)
            }

            Button {
                router.openChat(prefill: "Build today's workout from my recovery, sleep, recent training load, soreness, and goal.")
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Generate recovery-aware workout")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.biteInk)
                .padding(12)
                .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.98))
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
        .biteShadow(.raised)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.biteRedSoft)
                .padding(20)
                .background(.biteRedTint, in: Circle())
            Text("Start a strength session")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.biteInk)
            Text("Track sets, reps, rest, and volume now. Bite can still build a tailored plan from your recovery, goals, and constraints.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.biteInkMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button {
                    router.startWorkoutSession(defaultWorkoutContext)
                } label: {
                    Label("Start workout", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.biteRed, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    router.openChat(prefill: "Build me a workout for today")
                } label: {
                    Text("Ask Bite")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.biteInk)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.05), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }

    private var defaultWorkoutContext: WorkoutSessionContext {
        WorkoutSessionContext(
            id: UUID(),
            artifactID: nil,
            title: "Strength Session",
            exercises: [
                .init(id: UUID(), name: "Back Squat", muscleGroup: "Lower", sets: 3, reps: "8-10", restSec: 120),
                .init(id: UUID(), name: "Bench Press", muscleGroup: "Push", sets: 3, reps: "8-10", restSec: 120),
                .init(id: UUID(), name: "Bent Over Row", muscleGroup: "Pull", sets: 3, reps: "10", restSec: 90)
            ]
        )
    }

    private var workoutList: some View {
        VStack(spacing: 10) {
            ForEach(workouts) { w in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.biteRedTint)
                        Image(systemName: "figure.run")
                            .foregroundStyle(.biteRed)
                    }
                    .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.biteInk)
                        if let scheduled = w.scheduledAt {
                            Text(scheduled, format: .dateTime.weekday().hour().minute())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.biteInkFaint)
                        }
                    }
                    Spacer()
                    if w.completedAt != nil {
                        Text("DONE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(.biteRingRecovery)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
            }
        }
    }
}

private struct FitnessSignalTile: View {
    let title: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(.biteInkFaint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(unit)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.biteInkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
