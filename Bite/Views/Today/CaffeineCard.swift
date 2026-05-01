import SwiftUI
import SwiftData

/// Compact Today card mirroring the HydrationCard layout for caffeine.
/// Shows total mg / limit + a horizontal progress bar tinted to severity.
struct CaffeineCard: View {
    @Query(filter: #Predicate<SDDrinkEntry> { $0.kindRaw == "caffeine" })
    private var allCaffeine: [SDDrinkEntry]

    @Query private var profiles: [SDUserProfile]

    let onTap: () -> Void

    private var totalMg: Double {
        let day = Calendar.current.startOfDay(for: Date())
        let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let todayDrinks: [SDDrinkEntry] = allCaffeine.filter { $0.dayStart >= day && $0.dayStart < next }
        let mgValues: [Double] = todayDrinks.compactMap { $0.caffeineMg }
        return mgValues.reduce(0, +)
    }

    private var limitMg: Double {
        profiles.first?.caffeineLimitMg ?? 400
    }

    private var ratio: Double {
        guard limitMg > 0 else { return 0 }
        return min(1.0, totalMg / limitMg)
    }

    private var tint: Color {
        if ratio >= 1.0 { return .biteRed }
        if ratio >= 0.8 { return .biteWarning }
        return .biteCarbs
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("☕").font(.system(size: 14))
                    Text("CAFFEINE")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.biteInkMuted)
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(totalMg))")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.biteInk)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("/ \(Int(limitMg)) mg")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.biteInkFaint)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(0.12))
                            .frame(height: 8)
                        Capsule()
                            .fill(tint)
                            .frame(width: max(8, geo.size.width * ratio), height: 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: ratio)
                    }
                }
                .frame(height: 8)
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
