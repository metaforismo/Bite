import SwiftUI

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = BiteTheme.cardCornerRadius, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Color.white.opacity(0.7), in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glass card")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.biteInk)
                Text("Subtle white card with hairline stroke and soft shadow.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }
            .padding(16)
        }
        .padding()
    }
}
