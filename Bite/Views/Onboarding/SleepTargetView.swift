import SwiftUI

struct SleepTargetView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "moon.zzz.fill",
            iconColor: .biteRingSleep,
            title: "Set your sleep targets",
            subtitle: "Bite uses these to time your Smart Alarm and to score your recovery."
        ) {
            VStack(spacing: 18) {
                wakeTimeCard
                durationCard
            }
        } primaryAction: { onContinue() }
    }

    private var wakeTimeCard: some View {
        VStack(spacing: 10) {
            Text("Wake time")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.biteInkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            DatePicker(
                "",
                selection: wakeTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxHeight: 130)
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var durationCard: some View {
        VStack(spacing: 10) {
            Text("Sleep duration")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.biteInkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach([6, 7, 8, 9], id: \.self) { hours in
                    SleepHourPill(
                        hours: hours,
                        isSelected: vm.sleepTargetHours == hours
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            vm.sleepTargetHours = hours
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { vm.sleepTargetWakeTime ?? Self.defaultWakeTime() },
            set: { vm.sleepTargetWakeTime = $0 }
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.78))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
    }

    private static func defaultWakeTime() -> Date {
        var comps = DateComponents()
        comps.hour = 7
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}

private struct SleepHourPill: View {
    let hours: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(hours)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .biteInk)
                Text("hrs")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .biteInkMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.biteRingSleep : Color.white.opacity(0.78))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.biteRingSleep : Color.black.opacity(0.07),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        SleepTargetView(vm: OnboardingViewModel(), onContinue: {})
    }
}
