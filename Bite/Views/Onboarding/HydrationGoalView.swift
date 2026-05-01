import SwiftUI

struct HydrationGoalView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    private let presets: [Double] = [1500, 2000, 2500, 3000]

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Hydration",
            iconColor: .biteHydration,
            title: "Daily hydration goal",
            subtitle: "Most adults aim for 2–3 liters depending on activity and climate."
        ) {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { value in
                        let isSelected = abs(vm.hydrationGoalML - value) < 50
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                vm.hydrationGoalML = value
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", value / 1000))
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .biteInk)
                                Text("L")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .biteInkMuted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? Color.biteRed : Color.white.opacity(0.78))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.biteRed : Color.black.opacity(0.07),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Custom")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.biteInkMuted)
                        Spacer()
                        Text(String(format: "%.0f mL", vm.hydrationGoalML))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.biteInk)
                            .contentTransition(.numericText())
                    }
                    Slider(value: $vm.hydrationGoalML, in: 1000...4500, step: 50)
                        .tint(.biteHydration)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
                }
            }
        } primaryAction: { onContinue() }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        HydrationGoalView(vm: OnboardingViewModel(), onContinue: {})
    }
}
