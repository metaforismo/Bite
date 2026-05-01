import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    @State private var heroVisible = false
    @State private var titleVisible = false
    @State private var taglineVisible = false
    @State private var buttonVisible = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            heroOrb
                .scaleEffect(heroVisible ? 1 : 0.55)
                .opacity(heroVisible ? 1 : 0)

            VStack(spacing: 14) {
                Text("Bite")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .tracking(-1.5)
                    .foregroundStyle(.biteInk)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 16)

                Text("Your personal\nhealth agent.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.biteInkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(taglineVisible ? 1 : 0)
                    .offset(y: taglineVisible ? 0 : 12)
            }

            Spacer()

            Button {
                BiteHaptics.impact(.medium)
                onContinue()
            } label: {
                HStack(spacing: 8) {
                    Text("Let's go")
                        .font(.system(size: 17, weight: .heavy))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .buttonStyle(PressableProminentButtonStyle(tint: .biteRed))
            .padding(.horizontal, 24)
            .opacity(buttonVisible ? 1 : 0)
            .offset(y: buttonVisible ? 0 : 22)
        }
        .padding(.bottom, 48)
        .onAppear { runEntrance() }
    }

    private var heroOrb: some View {
        BiteOrbImage(size: 200, mood: .happy, state: .idle, showHalo: true)
    }

    private func runEntrance() {
        withAnimation(BiteMotion.onboardingHero.delay(0.05)) { heroVisible = true }
        withAnimation(BiteMotion.onboardingTitle.delay(0.30)) { titleVisible = true }
        withAnimation(BiteMotion.onboardingTitle.delay(0.50)) { taglineVisible = true }
        withAnimation(BiteMotion.onboardingCTA.delay(0.75)) { buttonVisible = true }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        WelcomeView(onContinue: {})
    }
}
