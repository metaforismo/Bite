import SwiftUI

struct ActivityLevelView: View {
    @Bindable var vm: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.biteOrange)

                Text("Activity level")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("How much do you move on a typical day?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 6) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            vm.activityLevel = level
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: level.icon)
                                .font(.body)
                                .frame(width: 24)
                                .foregroundStyle(vm.activityLevel == level ? Color.biteRed : .secondary)

                            Text(level.displayName)
                                .font(.subheadline)

                            Spacer()

                            if vm.activityLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.biteRed)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(vm.activityLevel == level ? Color.biteRed.opacity(0.08) : Color.clear)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
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
    }
}

#Preview {
    ActivityLevelView(vm: OnboardingViewModel(), onContinue: {})
}
