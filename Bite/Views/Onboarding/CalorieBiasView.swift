import SwiftUI

struct CalorieBiasView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.bitePurple)

                Text("Estimate precision")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("How should Bite estimate calories when in doubt?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Bias cards
            VStack(spacing: 10) {
                ForEach(CalorieBias.allCases, id: \.self) { bias in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            vm.calorieBias = bias
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: bias.icon)
                                .font(.title2)
                                .foregroundStyle(vm.calorieBias == bias ? Color.biteRed : .secondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(bias.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(bias.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if vm.calorieBias == bias {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.biteRed)
                            }
                        }
                        .padding(16)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(vm.calorieBias == bias ? Color.biteRed : Color.clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue Button
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.biteRed)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    CalorieBiasView(
        vm: OnboardingViewModel(),
        onContinue: {}
    )
}
