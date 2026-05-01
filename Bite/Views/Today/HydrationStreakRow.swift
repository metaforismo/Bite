import SwiftUI
import SwiftData

struct HydrationStreakRow: View {
    let onHydrationTap: () -> Void
    let streakDays: Int
    let last7Active: [Bool]          // 7 booleans, M..S

    var body: some View {
        HStack(spacing: 10) {
            HydrationCard(onTap: onHydrationTap)
            StreakCard(days: streakDays, week: last7Active)
        }
    }
}

/// Self-queries `SDDrinkEntry(kind: .water)` for today and `SDUserProfile` for the goal.
/// Tap opens the Hydration modal sheet.
struct HydrationCard: View {
    @Query(filter: #Predicate<SDDrinkEntry> { $0.kindRaw == "water" })
    private var allWater: [SDDrinkEntry]

    @Query private var profiles: [SDUserProfile]

    let onTap: () -> Void

    private var todayML: Double {
        let day = Calendar.current.startOfDay(for: Date())
        let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let todayDrinks: [SDDrinkEntry] = allWater.filter { $0.dayStart >= day && $0.dayStart < next }
        let volumes: [Double] = todayDrinks.compactMap { $0.volumeML }
        return volumes.reduce(0, +)
    }

    private var goalML: Double {
        profiles.first?.hydrationGoalML ?? 2500
    }

    private var liters: Double { todayML / 1000 }
    private var goalLiters: Double { goalML / 1000 }

    private var segments: [Bool] {
        let total = 8
        guard goalML > 0 else { return Array(repeating: false, count: total) }
        let filled = Int((todayML / goalML * Double(total)).rounded(.down))
        return (0..<total).map { $0 < filled }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("💧").font(.system(size: 14))
                    Text("HYDRATION")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.biteInkMuted)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(liters, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.biteInk)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("/ \(goalLiters, specifier: "%.1f") L")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.biteInkFaint)
                }
                HStack(spacing: 4) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, filled in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(filled ? Color.biteHydration : Color(hex: 0x5BA8E5).opacity(0.10))
                            .frame(maxWidth: .infinity)
                            .frame(height: 22)
                            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: filled)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct StreakCard: View {
    let days: Int
    let week: [Bool]
    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("🔥").font(.system(size: 14))
                Text("STREAK")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.biteInkMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(days)")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.biteInk)
                    .monospacedDigit()
                Text("days")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.biteInkFaint)
            }
            HStack(spacing: 3) {
                ForEach(Array(zip(dayLetters, week).enumerated()), id: \.offset) { _, pair in
                    Text(pair.0)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(pair.1 ? .white : .biteInkFaint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                        .background(pair.1 ? .biteRed : Color(hex: 0xF2EFEA),
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }
}
