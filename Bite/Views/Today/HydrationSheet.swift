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
                hydrationDial
                progressLine
                hydrationCoachCard
                quickAdds
                history
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    /// 24h timeline of intakes with the day's progress arc filled to
    /// `fillRatio`. Each drink renders as a small indicator dot at its
    /// hour. Stylized water-glass at center with fill height matching
    /// today's progress.
    private var hydrationDial: some View {
        let intakeIndicators: [DialIndicator] = todayWater.prefix(20).map { drink in
            DialIndicator(
                angle: DialClock.angle(forHour: hour(of: drink.timestamp)),
                color: .biteHydration,
                size: 9,
                inset: 12,
                systemImage: nil,
                glow: false
            )
        }

        let arc = DialArc(
            startAngle: 0,
            endAngle: 360 * Double(fillRatio),
            color: .biteHydration,
            width: 14,
            inset: 14
        )

        return OrbitDial(
            theme: .hydration,
            arcs: [arc],
            indicators: intakeIndicators
        ) {
            VStack(spacing: 4) {
                glass
                    .frame(width: 56, height: 78)
                Text("\(Int(fillRatio * 100))%")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.biteHydration)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: 280, maxHeight: 280)
        .padding(.top, 8)
    }

    /// Stylized glass-of-water that fills to today's % of goal.
    private var glass: some View {
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 4,
                style: .continuous
            )
            .stroke(Color.biteHydration.opacity(0.55), lineWidth: 2)

            UnevenRoundedRectangle(
                topLeadingRadius: 3,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12,
                topTrailingRadius: 3,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [Color.biteHydration.opacity(0.55), Color.biteHydration],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(maxHeight: 78 * fillRatio)
            .padding(2)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: fillRatio)
        }
    }

    private func hour(of date: Date) -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
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

    private var hydrationCoachCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(hydrationStatusTitle)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text(hydrationStatusSubtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                }
                Spacer()
                Image(systemName: "drop.degreesign.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.biteHydration)
                    .frame(width: 38, height: 38)
                    .background(Color.biteHydration.opacity(0.14), in: Circle())
            }

            HStack(spacing: 8) {
                HydrationStatPill(title: "Remaining", value: formatVolume(max(0, goalML - totalML)), tint: .biteHydration)
                HydrationStatPill(title: "Next", value: nextSipLabel, tint: .biteRingRecovery)
                HydrationStatPill(title: "Pace", value: paceLabel, tint: .biteCarbs)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
    }

    private var hydrationStatusTitle: String {
        if fillRatio >= 1 { return "Goal complete" }
        if fillRatio >= 0.7 { return "Almost there" }
        if todayWater.isEmpty { return "Start the day hydrated" }
        return "Keep sipping"
    }

    private var hydrationStatusSubtitle: String {
        if fillRatio >= 1 { return "Bite will stop nudging unless activity increases." }
        if fillRatio >= 0.7 { return "One larger drink should close the gap." }
        return "Small steady logs beat one huge catch-up later."
    }

    private var nextSipLabel: String {
        if fillRatio >= 1 { return "Done" }
        let remaining = max(0, goalML - totalML)
        return "\(Int(min(500, max(250, remaining)))) mL"
    }

    private var paceLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "AM" }
        if fillRatio >= 0.65 { return "Good" }
        return "Behind"
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

private struct HydrationStatPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(.biteInkFaint)
            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.biteInk)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
