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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.biteRedSoft)
                .padding(20)
                .background(.biteRedTint, in: Circle())
            Text("Ask Bite to propose a workout")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.biteInk)
            Text("Tell Bite your goal — recovery, strength, endurance — and it'll build a workout that respects your fatigue and constraints.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.biteInkMuted)
                .multilineTextAlignment(.center)
            Button {
                router.openChat(prefill: "Build me a workout for today")
            } label: {
                Text("Open Coach")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(.biteRed, in: Capsule())
            }
            .buttonStyle(.plain)
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
