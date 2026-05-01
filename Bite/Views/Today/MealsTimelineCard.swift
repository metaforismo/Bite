import SwiftUI

struct MealsTimelineCard: View {
    let entries: [FoodEntry]
    let consumedKcal: Int
    let goalKcal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY'S MEALS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.biteInkMuted)
                Spacer()
                Text("\(consumedKcal) / \(goalKcal) kcal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.biteInkFaint)
                    .monospacedDigit()
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                if entries.isEmpty {
                    EmptyMealsRow()
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                        MealRow(entry: entry, isLast: idx == entries.count - 1)
                    }
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
        }
    }
}

struct MealRow: View {
    let entry: FoodEntry
    let isLast: Bool

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: 0xFAF7F2))
                    Text(emoji(for: entry.text))
                        .font(.system(size: 18))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.text)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.biteInk)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(Self.timeFormatter.string(from: entry.createdAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.biteInkFaint)
                        if let confidence = entry.nutrition?.confidenceLevel {
                            Text("·")
                                .foregroundStyle(.biteInkFaint.opacity(0.5))
                            Text(confidence.label.uppercased())
                                .font(.system(size: 10.5, weight: .bold))
                                .tracking(0.3)
                                .foregroundStyle(.biteRingRecovery)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let calories = entry.nutrition?.calories {
                    HStack(spacing: 1) {
                        Text("\(calories)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.biteInk)
                            .monospacedDigit()
                        Text("kcal")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.biteInkFaint)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .overlay(Color.black.opacity(0.04))
                    .padding(.leading, 64)
            }
        }
    }

    private func emoji(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("salmon") || lower.contains("fish") { return "🐟" }
        if lower.contains("salad") || lower.contains("greens") { return "🥗" }
        if lower.contains("yogurt") || lower.contains("oats") { return "🥣" }
        if lower.contains("apple") || lower.contains("fruit") { return "🍎" }
        if lower.contains("egg") { return "🥚" }
        if lower.contains("chicken") { return "🍗" }
        if lower.contains("rice") || lower.contains("quinoa") { return "🍚" }
        if lower.contains("pasta") || lower.contains("noodle") { return "🍝" }
        if lower.contains("coffee") { return "☕️" }
        return "🍽️"
    }
}

private struct EmptyMealsRow: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("No meals logged yet")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.biteInk)
            Text("Tap Ask Bite to log a meal with a photo or text.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.biteInkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}
