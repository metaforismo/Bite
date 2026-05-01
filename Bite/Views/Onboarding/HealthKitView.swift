import SwiftUI

struct HealthKitView: View {
    let onContinue: () -> Void
    let onAuthorized: () -> Void

    @State private var isRequesting = false
    @State private var revealedRows: Int = 0

    private let benefits: [(icon: String, label: String, tint: Color)] = [
        ("figure.walk", "Daily steps", .biteRingRecovery),
        ("flame.fill", "Active calories", .biteOrange),
        ("scalemass", "Weight auto-sync", .biteBlue),
        ("fork.knife", "Save nutrition data", .biteRed),
    ]

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Heart",
            iconColor: .biteRed,
            title: "Connect Apple Health",
            subtitle: "Bite reads sleep, heart rate, weight, and more — and writes your nutrition back so everything stays in sync.",
            primaryActionTitle: isRequesting ? "Connecting…" : "Connect Apple Health",
            primaryActionLoading: isRequesting,
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(benefits.enumerated()), id: \.offset) { idx, benefit in
                    BenefitRow(icon: benefit.icon, label: benefit.label, tint: benefit.tint)
                        .opacity(idx < revealedRows ? 1 : 0)
                        .offset(x: idx < revealedRows ? 0 : -16)
                }
            }
            .padding(.top, 4)
            .onAppear { staggerReveal() }
        } primaryAction: {
            isRequesting = true
            Task {
                let authorized = await HealthKitService.shared.requestAuthorization()
                isRequesting = false
                if authorized {
                    BiteHaptics.success()
                    onAuthorized()
                }
                onContinue()
            }
        }
    }

    private func staggerReveal() {
        for i in 0..<benefits.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30 + Double(i) * 0.08) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    revealedRows = i + 1
                }
            }
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.14)))

            Text(label)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.biteInk)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.biteInkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        HealthKitView(onContinue: {}, onAuthorized: {})
    }
}
