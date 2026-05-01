import SwiftUI

struct CycleTrackingOptInView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconImageName: "CycleCalendar",
            iconColor: .biteRedSoft,
            title: "Track your cycle?",
            subtitle: "Bite reads HealthKit cycle data and shows phase-aware insights for energy, recovery, and nutrition. You can toggle this anytime in Settings."
        ) {
            VStack(spacing: 12) {
                CycleOptInCard(
                    title: "Yes, track my cycle",
                    subtitle: "Show the cycle card on Today and tailor coaching to my phase.",
                    icon: "checkmark.circle.fill",
                    isSelected: vm.cycleTrackingEnabled,
                    color: .biteRed
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.cycleTrackingEnabled = true
                    }
                }

                CycleOptInCard(
                    title: "Not now",
                    subtitle: "Skip this for now — you can enable it later in Settings.",
                    icon: "minus.circle",
                    isSelected: !vm.cycleTrackingEnabled,
                    color: .biteInkMuted
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.cycleTrackingEnabled = false
                    }
                }
            }
        } primaryAction: { onContinue() }
    }
}

private struct CycleOptInCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? color : .biteInkFaint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? color : Color.black.opacity(0.07),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        CycleTrackingOptInView(vm: OnboardingViewModel(), onContinue: {})
    }
}
