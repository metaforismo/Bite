import SwiftUI

/// Compact glass chip used in the Coach idle screen's quick-action row.
/// Pre-fills the composer with a starter prompt; never auto-submits.
///
/// Phase 4 redesign: dropped the heavy 240×88 card with subtitle in favor
/// of a small icon + title pill that morphs as Liquid Glass via
/// `GlassEffectContainer`. The composer below still owns the visual
/// weight; chips read as suggestions, not surfaces.
struct QuickActionCard: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let subtitle: String  // retained for API compat; no longer rendered
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.biteInk)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.94))
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .coach)
        GlassEffectContainer(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    QuickActionCard(
                        systemImage: "chart.line.uptrend.xyaxis",
                        iconColor: .biteRingRecovery,
                        title: "Predictive modeling",
                        subtitle: ""
                    ) {}
                    QuickActionCard(
                        systemImage: "fork.knife",
                        iconColor: .biteRed,
                        title: "Log food",
                        subtitle: ""
                    ) {}
                    QuickActionCard(
                        systemImage: "testtube.2",
                        iconColor: .biteHydration,
                        title: "Analyze labs",
                        subtitle: ""
                    ) {}
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
