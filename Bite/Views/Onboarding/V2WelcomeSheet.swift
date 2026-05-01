import SwiftUI

/// Shown once on first launch after upgrading from V1 (legacy onboarding completed,
/// no V2 marker set). Highlights the new V2 features and offers an opt-in mini
/// onboarding that captures only the new dimensions. Dismissing without setup
/// leaves all V2 fields at their defaults.
struct V2WelcomeSheet: View {
    let onSetupNewFeatures: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            BiteGradientBackground(style: .today)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: 12)

                    Image("BiteLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(spacing: 6) {
                        Text("Bite is bigger now")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.biteInk)
                        Text("Your nutrition diary just grew into a full health agent.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.biteInkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    VStack(spacing: 10) {
                        FeatureRow(
                            icon: "drop.fill",
                            color: .biteHydration,
                            title: "Hydration & caffeine",
                            sub: "Log every drink. Bite watches your day."
                        )
                        FeatureRow(
                            icon: "calendar.badge.clock",
                            color: .biteRedSoft,
                            title: "Cycle tracking",
                            sub: "Phase-aware insights, energy and recovery."
                        )
                        FeatureRow(
                            icon: "moon.zzz.fill",
                            color: .biteRingSleep,
                            title: "Smart Sleep Alarm",
                            sub: "Wake during light sleep within your window."
                        )
                        FeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            color: .biteOrange,
                            title: "Habit impact",
                            sub: "See which habits move your recovery score."
                        )
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 4)
                }
                .padding(.bottom, 32)
            }

            VStack {
                Spacer()
                BottomCTAStack(onSetupNewFeatures: onSetupNewFeatures, onSkip: onSkip)
            }
        }
    }
}

private struct BottomCTAStack: View {
    let onSetupNewFeatures: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onSetupNewFeatures) {
                Text("Set up new features")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.biteRed)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button(action: onSkip) {
                Text("Skip — I'll do it later")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let sub: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
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
    V2WelcomeSheet(onSetupNewFeatures: {}, onSkip: {})
}
