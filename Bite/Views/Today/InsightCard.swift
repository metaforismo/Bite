import SwiftUI

struct InsightCard: View {
    let title: String
    let message: String
    let onTapViewMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.biteRed)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.biteInk)
            }
            Text(message)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.biteInk.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onTapViewMore) {
                HStack(spacing: 4) {
                    Text("View full analysis")
                        .font(.system(size: 12.5, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.biteRed)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.biteRedTint, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 2)
    }
}
