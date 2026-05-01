import SwiftUI

struct StatusPill: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let sub: String
    let tint: Color

    @State private var iconBounce = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.85))
                    .shadow(color: iconColor.opacity(0.18), radius: 4, x: 0, y: 1)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .scaleEffect(iconBounce ? 1.08 : 1)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55).repeatForever(autoreverses: true), value: iconBounce)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text(sub)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .onAppear {
            // Tiny breathing on the status icon — keeps the row visually alive
            // without grabbing attention.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { iconBounce = true }
        }
    }
}
