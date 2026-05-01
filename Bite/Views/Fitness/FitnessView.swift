import SwiftUI
import SwiftData

struct FitnessView: View {
    @Bindable var router: BiteRouter
    @Query(sort: [SortDescriptor(\WorkoutArtifactModel.scheduledAt, order: .forward)])
    private var workouts: [WorkoutArtifactModel]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if workouts.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .padding(.top, 56)
            .padding(.bottom, BiteTheme.bottomFloatingClearance + 56)
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
