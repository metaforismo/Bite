import SwiftUI

struct HeightInputView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "ruler")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.biteBlue)

                Text("How tall are you?")
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
                        adjustHeight(by: -1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 2) {
                        TextField("170", text: $vm.heightCm)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 160)

                        Text("cm")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }

                    Button {
                        adjustHeight(by: 1)
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

    private func adjustHeight(by amount: Double) {
        let current = Double(vm.heightCm) ?? 170
        let newValue = max(100, min(250, current + amount))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            vm.heightCm = String(format: "%.0f", newValue)
        }
    }
}

#Preview {
    HeightInputView(vm: OnboardingViewModel(), onContinue: {})
}
