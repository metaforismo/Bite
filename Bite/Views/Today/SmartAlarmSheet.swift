import SwiftUI
import SwiftData

struct SmartAlarmSheet: View {
    @Bindable var router: BiteRouter

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\SDSmartAlarm.createdAt, order: .reverse)])
    private var existing: [SDSmartAlarm]

    @State private var wakeTime: Date = Self.defaultWakeTime()
    @State private var windowMinutes: Int = 20
    @State private var haptic: AlarmHapticIntensity = .progressive
    @State private var saveToWatch: Bool = true
    @State private var isSaving: Bool = false

    private let windowOptions = [10, 15, 20, 30]

    var body: some View {
        ModalSheetContainer(title: "Smart alarm", onClose: { router.closeModal() }) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    timePicker
                    windowPicker
                    hapticPicker
                    watchToggle
                    saveButton
                    if let active = existing.first {
                        cancelExisting(active)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .frame(maxHeight: 540)
            .onAppear { hydrate() }
        }
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Wake time")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxHeight: 130)
        }
        .padding(14)
        .background(card)
    }

    private var windowPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wake window")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            HStack(spacing: 8) {
                ForEach(windowOptions, id: \.self) { mins in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            windowMinutes = mins
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(mins)")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(windowMinutes == mins ? .white : .biteInk)
                            Text("min")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(windowMinutes == mins ? .white.opacity(0.85) : .biteInkMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(windowMinutes == mins ? Color.biteRingSleep : Color.white)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    windowMinutes == mins ? Color.biteRingSleep : Color.black.opacity(0.07),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(card)
    }

    private var hapticPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Haptic intensity")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            VStack(spacing: 6) {
                ForEach(AlarmHapticIntensity.allCases, id: \.self) { option in
                    HapticOptionRow(
                        option: option,
                        isSelected: haptic == option
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            haptic = option
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(card)
    }

    private var watchToggle: some View {
        Toggle(isOn: $saveToWatch) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Save to Apple Watch")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text("Mirrors automatically when paired with watchOS 26+.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }
        }
        .tint(.biteRingSleep)
        .padding(14)
        .background(card)
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                if isSaving { ProgressView().tint(.white) }
                Text(existing.isEmpty ? "Schedule alarm" : "Replace alarm")
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.biteRingSleep, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private func cancelExisting(_ alarm: SDSmartAlarm) -> some View {
        Button(role: .destructive) {
            Task {
                await CheckInService.shared.cancelSmartAlarm(alarm, in: modelContext)
                router.closeModal()
            }
        } label: {
            Text("Cancel current alarm (\(alarm.formattedWakeTime))")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.biteRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.biteRedTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var card: some ShapeStyle {
        Color.white
    }

    private func hydrate() {
        if let active = existing.first {
            var comps = DateComponents()
            comps.hour = active.targetHour
            comps.minute = active.targetMinute
            wakeTime = Calendar.current.date(from: comps) ?? Self.defaultWakeTime()
            windowMinutes = active.windowMinutes
            haptic = active.hapticIntensity
            saveToWatch = active.savedToWatch
        }
    }

    private func save() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
        let hour = comps.hour ?? 7
        let minute = comps.minute ?? 0
        isSaving = true
        Task {
            _ = try? await CheckInService.shared.scheduleSmartAlarm(
                targetHour: hour,
                targetMinute: minute,
                windowMinutes: windowMinutes,
                hapticIntensity: haptic,
                savedToWatch: saveToWatch,
                in: modelContext
            )
            isSaving = false
            router.closeModal()
        }
    }

    private static func defaultWakeTime() -> Date {
        var comps = DateComponents()
        comps.hour = 7
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}

private struct HapticOptionRow: View {
    let option: AlarmHapticIntensity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text(option.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.biteRingSleep)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.biteRingSleep.opacity(0.12) : Color.black.opacity(0.04))
            }
        }
        .buttonStyle(.plain)
    }
}
