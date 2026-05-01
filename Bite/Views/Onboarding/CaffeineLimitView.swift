import SwiftUI

struct CaffeineLimitView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    private let presets: [Double] = [200, 300, 400, 500]

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "cup.and.saucer.fill",
            iconColor: .biteCarbs,
            title: "Daily caffeine limit",
            subtitle: "The FDA suggests 400 mg as a safe daily ceiling for most healthy adults."
        ) {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { value in
                        let isSelected = abs(vm.caffeineLimitMg - value) < 25
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                vm.caffeineLimitMg = value
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(Int(value))")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .biteInk)
                                Text("mg")
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
                        Text("\(Int(vm.caffeineLimitMg)) mg")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.biteInk)
                            .contentTransition(.numericText())
                    }
                    Slider(value: $vm.caffeineLimitMg, in: 0...600, step: 25)
                        .tint(.biteCarbs)
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
        CaffeineLimitView(vm: OnboardingViewModel(), onContinue: {})
    }
}
