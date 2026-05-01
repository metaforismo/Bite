import SwiftUI
import UIKit

struct WidgetsTeaserView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconSystemName: "rectangle.stack.fill",
            iconColor: .biteRingRecovery,
            title: "Add Bite to your Home Screen",
            subtitle: "Five widgets keep your day in glance — rings, biomarkers, hydration, calories, and macros.",
            primaryActionTitle: "I'll add them later",
            secondaryActionTitle: "Open Settings",
            secondaryAction: openSettings
        ) {
            VStack(spacing: 14) {
                WidgetPreviewRow(
                    icon: "circle.dotted.circle.fill",
                    color: .biteRed,
                    title: "Daily Overview",
                    sub: "Three rings — nutrition, recovery, sleep"
                )
                WidgetPreviewRow(
                    icon: "drop.fill",
                    color: .biteHydration,
                    title: "Hydration",
                    sub: "Drop ring — 1.4 / 2.5 L"
                )
                WidgetPreviewRow(
                    icon: "battery.75percent",
                    color: .biteRingRecovery,
                    title: "Energy bank",
                    sub: "Remaining calories at a glance"
                )
            }
        } primaryAction: { onContinue() }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        onContinue()
    }
}

private struct WidgetPreviewRow: View {
    let icon: String
    let color: Color
    let title: String
    let sub: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.14))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text(sub)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }
            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.78))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        WidgetsTeaserView(onContinue: {})
    }
}
