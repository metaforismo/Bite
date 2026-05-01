import SwiftUI
import SwiftData

/// Active workout tracker. Vertically scrolls the exercise list; each exercise
/// has N set rows where the user enters weight + reps and taps a checkmark.
/// On checkmark, an inline rest timer starts and counts down. Finishing the
/// session writes an `SDStrengthSession` (with all sets) and dismisses back to
/// Today.
struct WorkoutSessionView: View {
    let context: WorkoutSessionContext
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var session: SDStrengthSession
    @State private var showingPlateFor: PlateBindingTarget?
    @State private var showingDiscardConfirm = false

    init(context: WorkoutSessionContext, onFinish: @escaping () -> Void) {
        self.context = context
        self.onFinish = onFinish

        // Pre-instantiate empty SDStrengthSet rows for every (exercise, set index).
        let initialSets: [SDStrengthSet] = context.exercises.flatMap { exercise in
            (0..<max(1, exercise.sets)).map { idx in
                SDStrengthSet(exerciseName: exercise.name, setIndex: idx)
            }
        }
        let session = SDStrengthSession(
            workoutArtifactID: context.artifactID,
            title: context.title,
            sets: initialSets
        )
        self._session = State(initialValue: session)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BiteGradientBackground(style: .today)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    exerciseList
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            finishBar
        }
        .alert("Discard workout?", isPresented: $showingDiscardConfirm) {
            Button("Discard", role: .destructive) { onFinish() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Sets you've already logged will be lost.")
        }
        .sheet(item: $showingPlateFor) { target in
            PlateCalculatorSheet(
                weightLb: bindingFor(target),
                onClose: { showingPlateFor = nil }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.biteInk)
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    Text(formatElapsed(context.date.timeIntervalSince(session.startedAt)))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.biteInkMuted)
                        .monospacedDigit()
                }
            }
            Spacer()
            Button {
                showingDiscardConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.biteInk)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.92)))
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var exerciseList: some View {
        VStack(spacing: 14) {
            ForEach(context.exercises) { exercise in
                ExerciseSection(
                    exercise: exercise,
                    sets: setsFor(exercise),
                    onTapWeight: { setID in
                        showingPlateFor = PlateBindingTarget(setID: setID)
                    },
                    onComplete: { setID in
                        completeSet(setID: setID, restSec: exercise.restSec)
                    }
                )
            }
        }
    }

    private var finishBar: some View {
        Button {
            finish()
        } label: {
            HStack {
                Image(systemName: "checkmark")
                Text("Finish workout")
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.biteRed, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func setsFor(_ exercise: WorkoutSessionContext.Exercise) -> [SDStrengthSet] {
        session.sets
            .filter { $0.exerciseName == exercise.name }
            .sorted { $0.setIndex < $1.setIndex }
    }

    private func bindingFor(_ target: PlateBindingTarget) -> Binding<Double> {
        Binding(
            get: { session.sets.first(where: { $0.id == target.setID })?.weightLb ?? 0 },
            set: { newValue in
                if let row = session.sets.first(where: { $0.id == target.setID }) {
                    row.weightLb = newValue
                }
            }
        )
    }

    private func completeSet(setID: UUID, restSec: Int) {
        if let row = session.sets.first(where: { $0.id == setID }) {
            row.completedAt = Date()
        }
    }

    private func finish() {
        session.completedAt = Date()
        modelContext.insert(session)
        try? modelContext.save()
        onFinish()
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

private struct PlateBindingTarget: Identifiable {
    let setID: UUID
    var id: UUID { setID }
}

private struct ExerciseSection: View {
    let exercise: WorkoutSessionContext.Exercise
    let sets: [SDStrengthSet]
    let onTapWeight: (UUID) -> Void
    let onComplete: (UUID) -> Void

    @State private var activeRestEndAt: [UUID: Date] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.biteInk)
                if let group = exercise.muscleGroup {
                    Text(group.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(.biteInkFaint)
                }
                Spacer()
                if let reps = exercise.reps {
                    Text("\(exercise.sets) × \(reps)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.biteInkMuted)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                    SetRow(
                        index: idx,
                        set: set,
                        onTapWeight: { onTapWeight(set.id) },
                        onComplete: {
                            onComplete(set.id)
                            activeRestEndAt[set.id] = Date().addingTimeInterval(TimeInterval(exercise.restSec))
                        }
                    )

                    if let endAt = activeRestEndAt[set.id], endAt > Date() {
                        RestTimerRow(endAt: endAt) {
                            activeRestEndAt.removeValue(forKey: set.id)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }
}

private struct SetRow: View {
    let index: Int
    @Bindable var set: SDStrengthSet
    let onTapWeight: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.biteInkMuted)
                .frame(width: 22)

            Button(action: onTapWeight) {
                HStack(spacing: 2) {
                    Text("\(Int(set.weightLb))")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text("lb")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                TextField("0", value: $set.reps, format: .number)
                    .font(.system(size: 14, weight: .heavy))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                    }
                Text("reps")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
            }

            Button(action: onComplete) {
                Image(systemName: set.completedAt == nil ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(set.completedAt == nil ? Color.biteInkFaint : .biteRingRecovery)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RestTimerRow: View {
    let endAt: Date
    let onTimerEnd: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = max(0, endAt.timeIntervalSince(ctx.date))
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
                Text(formatRest(remaining))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.biteInkMuted)
                    .monospacedDigit()
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.biteRedTint)
            }
            .onChange(of: remaining) { _, value in
                if value <= 0 { onTimerEnd() }
            }
        }
    }

    private func formatRest(_ s: TimeInterval) -> String {
        let total = Int(s)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
