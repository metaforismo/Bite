import SwiftUI

/// Second onboarding step. Communicates the product positioning:
///   1. Coach is the main thing (ChatGPT for health)
///   2. Photo OR natural-language meal logging
///   3. Home + other tabs are dashboards over the data Coach captures
///
/// Three illustrated points, no walls of text. Liquid-glass chips
/// referencing the actual chip style used in Coach idle.
struct HowItWorksView: View {
    let onContinue: () -> Void

    @State private var step1Visible = false
    @State private var step2Visible = false
    @State private var step3Visible = false
    @State private var ctaVisible = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 8)

            VStack(spacing: 8) {
                Text("How Bite works")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(.biteInk)
                Text("Three things to know")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }

            VStack(spacing: 14) {
                row(
                    icon: "sparkles",
                    iconBg: LinearGradient(colors: [Color(hex: 0x7C6BD9), Color(hex: 0x5B4DC9)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "Bite is a chat for your health",
                    body: "Talk to Bite like ChatGPT — about food, sleep, water, training, lab results. It tracks what matters and answers in plain language.",
                    visible: step1Visible
                )
                row(
                    icon: "fork.knife",
                    iconBg: LinearGradient(colors: [Color(hex: 0xFFB088), Color(hex: 0xF43F3F)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "Log meals by photo or words",
                    body: "Send a snap of your plate, or just write \"two scrambled eggs and toast\". Bite estimates macros, asks for a tweak if you want, then saves it to today.",
                    visible: step2Visible
                )
                row(
                    icon: "square.grid.2x2.fill",
                    iconBg: LinearGradient(colors: [Color(hex: 0x9DD9F3), Color(hex: 0x5BA8E5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    title: "Home, Journal, Fitness, Biology",
                    body: "Dashboards over the data Bite captures. Long-press any card to ask Bite about it.",
                    visible: step3Visible
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                BiteHaptics.impact(.medium)
                onContinue()
            } label: {
                HStack(spacing: 8) {
                    Text("Got it")
                        .font(.system(size: 17, weight: .heavy))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .buttonStyle(PressableProminentButtonStyle(tint: .biteRed))
            .padding(.horizontal, 24)
            .opacity(ctaVisible ? 1 : 0)
            .offset(y: ctaVisible ? 0 : 14)
        }
        .padding(.bottom, 36)
        .onAppear { runEntrance() }
    }

    private func row(
        icon: String,
        iconBg: LinearGradient,
        title: String,
        body: String,
        visible: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 46, height: 46)
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text(body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 18)
    }

    private func runEntrance() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78).delay(0.10)) { step1Visible = true }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78).delay(0.25)) { step2Visible = true }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78).delay(0.40)) { step3Visible = true }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78).delay(0.60)) { ctaVisible = true }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        HowItWorksView(onContinue: {})
    }
}
