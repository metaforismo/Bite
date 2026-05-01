import SwiftUI

struct WorkoutPayload: Decodable, Sendable {
    let title: String
    let summary: String?
    let exercises: [Exercise]
    let device: String?

    struct Exercise: Decodable, Identifiable, Sendable {
        let id: UUID
        let name: String
        let equipment: String
        let sets: Int
        let reps: String?
        let restSec: Int?
        let muscleGroup: String?
    }
}

struct WorkoutCard: View {
    let artifact: ArtifactMessage
    @Environment(BiteRouter.self) private var router
    @State private var payload: WorkoutPayload?
    @State private var expanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let p = payload {
                header(p)
                if expanded {
                    VStack(spacing: 6) {
                        ForEach(p.exercises) { ex in
                            ExerciseRow(exercise: ex)
                        }
                    }
                }
                actions(p)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 2)
        .onAppear { decode() }
        .onChange(of: artifact.version) { _, _ in decode() }
    }

    private func header(_ p: WorkoutPayload) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.biteRed)
                    Text("WORKOUT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.biteInkFaint)
                }
                Text(p.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.biteInk)
                if let summary = p.summary {
                    Text(summary)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                }
            }
            Spacer()
            Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { expanded.toggle() } } label: {
                HStack(spacing: 2) {
                    Text(expanded ? "Collapse" : "View")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: expanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.biteRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.biteRedTint, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func actions(_ p: WorkoutPayload) -> some View {
        HStack(spacing: 8) {
            Button {
                router.startWorkoutSession(buildContext(p))
            } label: {
                Text("Start")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.biteInk, in: Capsule())
            }
            .buttonStyle(.plain)

            if let device = p.device {
                Text(device)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0xF2EFEC), in: Capsule())
            }
        }
    }

    private func buildContext(_ p: WorkoutPayload) -> WorkoutSessionContext {
        let exercises: [WorkoutSessionContext.Exercise] = p.exercises.map { ex in
            WorkoutSessionContext.Exercise(
                id: ex.id,
                name: ex.name,
                muscleGroup: ex.muscleGroup,
                sets: max(1, ex.sets),
                reps: ex.reps,
                restSec: ex.restSec ?? 60
            )
        }
        return WorkoutSessionContext(
            id: UUID(),
            artifactID: artifact.id,
            title: p.title,
            exercises: exercises
        )
    }

    private func decode() {
        guard let decoded = try? JSONDecoder.bite.decode(WorkoutPayload.self, from: artifact.payloadJSON) else { return }
        payload = decoded
    }
}

private struct ExerciseRow: View {
    let exercise: WorkoutPayload.Exercise

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0xF2EFEC))
                Image(systemName: iconName(for: exercise.muscleGroup))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.biteInk)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInk)
                Text(exercise.equipment)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(exercise.sets) sets")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.biteInk)
                if let reps = exercise.reps {
                    Text(reps)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.biteInkFaint)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0xFAFAFA), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func iconName(for group: String?) -> String {
        switch group?.lowercased() {
        case "chest", "push": return "figure.strengthtraining.functional"
        case "back", "pull": return "figure.strengthtraining.traditional"
        case "legs": return "figure.run"
        case "core": return "figure.core.training"
        default: return "dumbbell.fill"
        }
    }
}
