import SwiftUI

struct WeightInputView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "scalemass")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.biteBlue)

                Text("How much do you weigh?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Used to estimate your basal metabolic rate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Button {
                        adjustWeight(by: -0.5)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 2) {
                        TextField("70", text: $vm.weightKg)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 160)

                        Text("kg")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }

                    Button {
                        adjustWeight(by: 0.5)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
            .padding(.horizontal, 24)

            Spacer()

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
        .scrollDismissesKeyboard(.interactively)
    }

    private func adjustWeight(by amount: Double) {
        let current = Double(vm.weightKg) ?? 70
        let newValue = max(30, current + amount)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            vm.weightKg = String(format: "%.1f", newValue)
        }
    }
}

#Preview {
    WeightInputView(vm: OnboardingViewModel(), onContinue: {})
}
