import SwiftUI

struct AgeInputView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.biteBlue)

                Text("How old are you?")
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
                        adjustAge(by: -1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 2) {
                        TextField("25", text: $vm.age)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 120)

                        Text("years")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }

                    Button {
                        adjustAge(by: 1)
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

    private func adjustAge(by amount: Int) {
        let current = Int(vm.age) ?? 25
        let newValue = max(16, min(100, current + amount))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            vm.age = "\(newValue)"
        }
    }
}

#Preview {
    AgeInputView(vm: OnboardingViewModel(), onContinue: {})
}
