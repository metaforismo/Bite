import SwiftUI

struct ThinkingCascade: View {
    let steps: [CoachChatViewModel.ThinkingStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Thinking…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInk)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }
            ForEach(steps) { step in
                ThinkingRow(label: step.label, done: step.done)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(BiteMotion.thinkingRise, value: steps.count)
    }
}

struct ThinkingRow: View {
    let label: String
    let done: Bool
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            if done {
                Circle()
                    .fill(.biteRedTint)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.biteRed)
                    )
            } else {
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(Color.biteRed, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.biteInkMuted)
        }
        .padding(.vertical, 5)
    }
}
