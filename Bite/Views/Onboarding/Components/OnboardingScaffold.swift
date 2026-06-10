import SwiftUI

/// Shared layout primitive for every onboarding page: animated icon hero,
/// staggered title + subtitle reveal, content slot, primary CTA, optional
/// secondary action. Selection feedback is haptic by default.
///
/// All pages compose this scaffold so styling stays consistent (warm radial
/// gradient + biteRed CTAs + identical spacing). The orchestrating
/// `OnboardingView` owns the back button + progress bar — pages just fill the slot.
struct OnboardingScaffold<Content: View>: View {
    let iconSystemName: String?
    let iconImageName: String?
    let iconColor: Color
    let title: String
    let subtitle: String?
    let content: Content
    let primaryActionTitle: String
    let primaryActionDisabled: Bool
    let primaryActionLoading: Bool
    let primaryAction: () -> Void
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    @State private var heroVisible = false
    @State private var titleVisible = false
    @State private var contentVisible = false
    @State private var halo = false

    init(
        iconSystemName: String? = nil,
        iconImageName: String? = nil,
        iconColor: Color = .biteRed,
        title: String,
        subtitle: String? = nil,
        primaryActionTitle: String = "Continue",
        primaryActionDisabled: Bool = false,
        primaryActionLoading: Bool = false,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        primaryAction: @escaping () -> Void
    ) {
        self.iconSystemName = iconSystemName
        self.iconImageName = iconImageName
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionDisabled = primaryActionDisabled
        self.primaryActionLoading = primaryActionLoading
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.content = content()
        self.primaryAction = primaryAction
    }

    var body: some View {
        VStack(spacing: 28) {
            // Top spacing is owned by the parent (`OnboardingView`) so the
            // hero icon can land on the 150pt reserved-zone boundary
            // regardless of safe area.
            Spacer(minLength: 0)

            // Hero ----------------------------------------------------------
            VStack(spacing: 14) {
                heroIcon
                    .scaleEffect(heroVisible ? 1 : 0.6)
                    .opacity(heroVisible ? 1 : 0)

                Text(title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.biteInk)
                    .padding(.horizontal, 24)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 12)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(titleVisible ? 1 : 0)
                        .offset(y: titleVisible ? 0 : 10)
                }
            }

            content
                .padding(.horizontal, 24)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 8)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Button {
                    BiteHaptics.impact(.light)
                    primaryAction()
                } label: {
                    HStack(spacing: 8) {
                        if primaryActionLoading {
                            ProgressView().tint(.white)
                        }
                        Text(primaryActionTitle)
                            .font(.system(size: 16, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(PressableProminentButtonStyle())
                .disabled(primaryActionDisabled || primaryActionLoading)

                if let secondaryActionTitle, let secondaryAction {
                    Button {
                        BiteHaptics.selection()
                        secondaryAction()
                    } label: {
                        Text(secondaryActionTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.biteInkMuted)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 12)
        }
        .onAppear { runEntranceAnimation() }
    }

    @ViewBuilder
    private var heroIcon: some View {
        ZStack {
            // Soft pulsing halo behind the hero — gives the icon a "breathing" quality.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [iconColor.opacity(0.32), iconColor.opacity(0)],
                        center: .center,
                        startRadius: 8,
                        endRadius: 56
                    )
                )
                .frame(width: 116, height: 116)
                .scaleEffect(halo ? 1.08 : 0.92)
                .opacity(halo ? 0.95 : 0.55)
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: halo)

            if let imageName = iconImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
            } else if let symbol = iconSystemName {
                Image(systemName: symbol)
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 76, height: 76)
                    .background {
                        Circle()
                            .fill(iconColor.opacity(0.14))
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(iconColor.opacity(0.25), lineWidth: 1)
                    }
            }
        }
        .onAppear { halo = true }
    }

    private func runEntranceAnimation() {
        withAnimation(BiteMotion.onboardingHero) { heroVisible = true }
        withAnimation(BiteMotion.onboardingTitle.delay(0.10)) { titleVisible = true }
        withAnimation(BiteMotion.onboardingTitle.delay(0.20)) { contentVisible = true }
    }
}

/// Standard prominent button style with a subtle press-scale that makes the
/// CTA feel physical without losing its chunky filled look.
struct PressableProminentButtonStyle: ButtonStyle {
    var tint: Color = .biteRed

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct OnboardingNumberCard: View {
    @Binding var value: String
    let placeholder: String
    let unit: String
    let allowsDecimal: Bool
    let decrement: () -> Void
    let increment: () -> Void
    var footnote: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                stepButton("minus", action: decrement)
                VStack(spacing: 2) {
                    TextField(placeholder, text: $value)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.biteInk)
                        .frame(width: 150)
                        .minimumScaleFactor(0.65)
                    Text(unit)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInkMuted)
                }
                stepButton("plus", action: increment)
            }
            if let footnote {
                Text(footnote)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(22)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        .biteShadow(.raised)
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            BiteHaptics.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.biteInk)
                .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.05), in: Circle())
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.94))
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        OnboardingScaffold(
            iconSystemName: "drop.fill",
            iconColor: .biteHydration,
            title: "Daily hydration goal",
            subtitle: "Adults need 2–3 liters per day depending on activity and climate.",
            secondaryActionTitle: "Skip",
            secondaryAction: {}
        ) {
            Text("Picker placeholder")
                .padding()
        } primaryAction: {}
    }
}
