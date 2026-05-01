import SwiftUI
import SwiftData

struct HydrationSheet: View {
    @Bindable var router: BiteRouter

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<SDDrinkEntry> { $0.kindRaw == "water" })
    private var allWater: [SDDrinkEntry]

    @Query private var profiles: [SDUserProfile]

    private var profile: SDUserProfile? { profiles.first }

    private var todayWater: [SDDrinkEntry] {
        let day = Calendar.current.startOfDay(for: Date())
        let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        return allWater
            .filter { $0.dayStart >= day && $0.dayStart < next }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var totalML: Double {
        todayWater.compactMap(\.volumeML).reduce(0, +)
    }

    private var goalML: Double {
        profile?.hydrationGoalML ?? 2500
    }

    private var fillRatio: CGFloat {
        guard goalML > 0 else { return 0 }
        return min(1, CGFloat(totalML / goalML))
    }

    var body: some View {
        ModalSheetContainer(title: "Hydration", onClose: { router.closeModal() }) {
            VStack(spacing: 18) {
                glassPreview
                progressLine
                quickAdds
                history
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private var glassPreview: some View {
        ZStack(alignment: .bottom) {
            // Glass outline
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 6,
                style: .continuous
            )
            .stroke(Color.biteHydration.opacity(0.45), lineWidth: 3)

            // Fill
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 4,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [Color.biteHydration.opacity(0.55), Color.biteHydration],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(height: 128 * fillRatio)
            .padding(3)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: fillRatio)
        }
        .frame(width: 86, height: 128)
        .padding(.top, 8)
    }

    private var progressLine: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatVolume(totalML))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.biteInk)
                    .contentTransition(.numericText())
                Text("/ \(formatVolume(goalML))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
            }

            ProgressView(value: Double(fillRatio))
                .tint(.biteHydration)
                .frame(maxWidth: 240)
        }
    }

    private var quickAdds: some View {
        HStack(spacing: 10) {
            ForEach([250.0, 350.0, 500.0, 750.0], id: \.self) { ml in
                Button {
                    add(ml: ml)
                } label: {
                    VStack(spacing: 0) {
                        Text("+\(Int(ml))")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.biteInk)
                        Text("mL")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.biteInkMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.biteHydration.opacity(0.12))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.biteHydration.opacity(0.35), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)

            if todayWater.isEmpty {
                Text("No drinks logged yet today.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
                    .padding(.vertical, 8)
            } else {
                ForEach(todayWater) { drink in
                    HStack(spacing: 10) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.biteHydration)
                        Text(drink.timestamp, format: .dateTime.hour().minute())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.biteInkMuted)
                            .frame(width: 60, alignment: .leading)
                        Text(formatVolume(drink.volumeML ?? 0))
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.biteInk)
                        Spacer()
                        Button(role: .destructive) {
                            delete(drink)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.biteInkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                    }
                }
            }
        }
    }

    private func add(ml: Double) {
        let entry = SDDrinkEntry(kind: .water, volumeML: ml, label: nil)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func delete(_ drink: SDDrinkEntry) {
        modelContext.delete(drink)
        try? modelContext.save()
    }

    private func formatVolume(_ ml: Double) -> String {
        if ml >= 1000 {
            return String(format: "%.1f L", ml / 1000)
        }
        return "\(Int(ml)) mL"
    }
}
