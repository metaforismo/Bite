import SwiftUI

/// Large card used in the Coach idle screen's quick-action row. Pre-fills
/// the composer with a starter prompt; never auto-submits — the user can
/// edit the text before sending.
///
/// Sized so that two cards fit on a standard iPhone width with a third
/// card peeking on the right edge to signal scrollability.
struct QuickActionCard: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(width: 240, height: 88)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableScaleButtonStyle())
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .coach)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionCard(
                    systemImage: "chart.line.uptrend.xyaxis",
                    iconColor: .biteRingRecovery,
                    title: "Predictive modeling",
                    subtitle: "Forecast your metrics"
                ) {}
                QuickActionCard(
                    systemImage: "fork.knife",
                    iconColor: .biteRed,
                    title: "Log food",
                    subtitle: "Track your daily intake"
                ) {}
                QuickActionCard(
                    systemImage: "testtube.2",
                    iconColor: .biteHydration,
                    title: "Analyze labs",
                    subtitle: "Review bloodwork"
                ) {}
            }
            .padding(.horizontal, 16)
        }
    }
}
