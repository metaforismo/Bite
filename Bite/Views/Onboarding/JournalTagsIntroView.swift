import SwiftUI

struct JournalTagsIntroView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Charts",
            iconColor: .biteOrange,
            title: "See what's driving you",
            subtitle: "Bite quietly tags habits like late meals, alcohol, and stress, then shows you which ones move your recovery score — so you can stop guessing.",
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            VStack(spacing: 10) {
                tagRow(emoji: "🌙", label: "Late meal", impact: "−11% recovery", negative: true)
                tagRow(emoji: "🥗", label: "67+ nutrition score", impact: "+8% recovery", negative: false)
                tagRow(emoji: "🍷", label: "Alcohol", impact: "−14% recovery", negative: true)
                tagRow(emoji: "🚶‍♂️", label: "10k+ steps", impact: "+12% recovery", negative: false)
            }
        } primaryAction: { onContinue() }
    }

    private func tagRow(emoji: String, label: String, impact: String, negative: Bool) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .background {
                    Circle().fill(Color.white.opacity(0.78))
                }

            Text(label)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.biteInk)

            Spacer()

            Text(impact)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(negative ? .biteRed : .biteRingRecovery)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule().fill(
                        (negative ? Color.biteRedTint : Color.biteRingRecovery.opacity(0.14))
                    )
                }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        JournalTagsIntroView(onContinue: {})
    }
}
