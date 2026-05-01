import SwiftUI

struct UpNextItem: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let sub: String
    let systemImage: String
    let tint: Color
}

struct UpNextCard: View {
    let items: [UpNextItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UP NEXT")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
                .padding(.leading, 4)
            VStack(spacing: 8) {
                if items.isEmpty {
                    Text("No upcoming check-ins. Ask Bite to schedule one.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.biteInkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.04), lineWidth: 1)
                        )
                } else {
                    ForEach(items) { item in
                        UpNextRow(item: item)
                    }
                }
            }
        }
    }
}

struct UpNextRow: View {
    let item: UpNextItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.tint)
                Image(systemName: item.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.biteInk)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.biteInk)
                Text(item.sub)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.time)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.biteInkMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 1)
    }
}
