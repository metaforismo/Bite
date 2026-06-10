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

    @State private var session: SDStrengthSession?

    var body: some View {
        Group {
            if let session {
                WorkoutSessionContent(context: context, session: session, onFinish: onFinish)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BiteGradientBackground(style: .today))
        .onAppear {
            if let session {
                if !session.sets.contains(where: { $0.completedAt != nil }) {
                    session.startedAt = .now
                }
            } else {
                // Pre-instantiate empty SDStrengthSet rows for every (exercise, set index).
                let initialSets: [SDStrengthSet] = context.exercises.flatMap { exercise in
                    (0..<max(1, exercise.sets)).map { idx in
                        SDStrengthSet(exerciseName: exercise.name, setIndex: idx)
                    }
                }
                session = SDStrengthSession(
                    workoutArtifactID: context.artifactID,
                    title: context.title,
                    sets: initialSets
                )
            }
        }
    }
}

private struct WorkoutSessionContent: View {
    let context: WorkoutSessionContext
    @Bindable var session: SDStrengthSession
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showingPlateFor: PlateBindingTarget?
    @State private var showingDiscardConfirm = false
    @State private var showingEmptyFinishConfirm = false
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var extraExercises: [WorkoutSessionContext.Exercise] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                header
                sessionProgress
                exerciseList
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
                }
                .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.98))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            finishBar
        }
        .alert("Discard workout?", isPresented: $showingDiscardConfirm) {
            Button("Discard", role: .destructive) { onFinish() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Sets you've already logged will be lost.")
        }
        .alert("Nothing logged — discard this workout?", isPresented: $showingEmptyFinishConfirm) {
            Button("Discard", role: .destructive) { onFinish() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $showingPlateFor) { target in
            PlateCalculatorSheet(
                weightLb: bindingFor(target),
                onClose: { showingPlateFor = nil }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAddExercise) {
            addExerciseSheet
                .presentationDetents([.height(240)])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.biteInk)
                    .lineLimit(1)
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    Text(formatElapsed(context.date.timeIntervalSince(session.startedAt)))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.biteInkMuted)
                        .monospacedDigit()
                }
            }
            Spacer()
            Menu {
                Button("Discard workout", systemImage: "trash", role: .destructive) {
                    showingDiscardConfirm = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.biteInk)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.92)))
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var sessionProgress: some View {
        let total = max(1, session.sets.count)
        let done = session.sets.filter { $0.completedAt != nil }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(done)/\(total) sets")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.biteInk)
                    .monospacedDigit()
                Spacer()
                Text("\(activeExercises.count) exercises")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.biteInkMuted)
            }
            ProgressView(value: Double(done), total: Double(total))
                .tint(.biteRingRecovery)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
    }

    private var exerciseList: some View {
        VStack(spacing: 10) {
            ForEach(activeExercises) { exercise in
                ExerciseSection(
                    exercise: exercise,
                    sets: setsFor(exercise),
                    onTapWeight: { setID in
                        showingPlateFor = PlateBindingTarget(setID: setID)
                    },
                    onComplete: { setID in
                        completeSet(setID: setID, restSec: exercise.restSec)
                    },
                    onAddSet: { addSet(to: exercise) }
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
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var activeExercises: [WorkoutSessionContext.Exercise] {
        context.exercises + extraExercises
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

    private func addSet(to exercise: WorkoutSessionContext.Exercise) {
        let count = setsFor(exercise).count
        let previous = setsFor(exercise).last
        let row = SDStrengthSet(
            exerciseName: exercise.name,
            setIndex: count,
            weightLb: previous?.weightLb ?? 0,
            reps: previous?.reps ?? 0
        )
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            session.sets.append(row)
        }
    }

    private var addExerciseSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add exercise")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.biteInk)
            TextField("Exercise name", text: $newExerciseName)
                .font(.system(size: 17, weight: .semibold))
                .padding(14)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button {
                let name = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let exercise = WorkoutSessionContext.Exercise(
                    id: UUID(),
                    name: name,
                    muscleGroup: nil,
                    sets: 1,
                    reps: nil,
                    restSec: 90
                )
                extraExercises.append(exercise)
                session.sets.append(SDStrengthSet(exerciseName: name, setIndex: 0))
                newExerciseName = ""
                showingAddExercise = false
            } label: {
                Text("Add")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.biteInkFaint : Color.biteInk, in: Capsule())
            }
            .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer()
        }
        .padding(20)
        .background(Color.white)
    }

    private func finish() {
        guard session.sets.contains(where: { $0.completedAt != nil }) else {
            showingEmptyFinishConfirm = true
            return
        }
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
    let onAddSet: () -> Void

    @State private var activeRestEndAt: [UUID: Date] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            HStack(spacing: 8) {
                Text("SET")
                    .frame(width: 26)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
                Text("")
                    .frame(width: 30)
            }
            .font(.system(size: 9.5, weight: .heavy))
            .foregroundStyle(.biteInkFaint)

            VStack(spacing: 6) {
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

            Button(action: onAddSet) {
                Label("Add set", systemImage: "plus")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.biteInkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.98))
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
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
                .frame(width: 26)

            Button(action: onTapWeight) {
                HStack(spacing: 2) {
                    Text("\(Int(set.weightLb))")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text("lb")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 34)
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
                    .frame(maxWidth: .infinity, minHeight: 34)
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
