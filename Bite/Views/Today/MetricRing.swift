import SwiftUI

struct MetricRing: View {
    let percent: Double             // 0...1
    let color: Color
    let title: String
    let sub: String

    @State private var animatedPercent: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.13), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(0, min(1, animatedPercent)))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(percentText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.biteInk)
                    .monospacedDigit()
            }
            .frame(width: 76, height: 76)
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.biteInk)
                Text(sub)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(BiteMotion.ringDraw) { animatedPercent = percent }
        }
        .onChange(of: percent) { _, newValue in
            withAnimation(BiteMotion.ringDraw) { animatedPercent = newValue }
        }
    }

    private var percentText: String {
        let p = Int(round(percent * 100))
        return "\(p)%"
    }
}

struct RingsCard: View {
    let nutrition: Double
    let recovery: Double
    let sleep: Double
    let nutritionSub: String
    let recoverySub: String
    let sleepSub: String
    var onSleepTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            MetricRing(percent: nutrition, color: .biteRingNutrition, title: "Nutrition", sub: nutritionSub)
            MetricRing(percent: recovery,  color: .biteRingRecovery,  title: "Recovery",  sub: recoverySub)
            Button {
                onSleepTap?()
            } label: {
                MetricRing(percent: sleep, color: .biteRingSleep, title: "Sleep", sub: sleepSub)
            }
            .buttonStyle(.plain)
            .disabled(onSleepTap == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }
}
