import SwiftUI
import SwiftData

struct CaffeineSheet: View {
    @Bindable var router: BiteRouter

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<SDDrinkEntry> { $0.kindRaw == "caffeine" })
    private var allCaffeine: [SDDrinkEntry]

    @Query private var profiles: [SDUserProfile]

    private var profile: SDUserProfile? { profiles.first }

    private var todayDrinks: [SDDrinkEntry] {
        let day = Calendar.current.startOfDay(for: Date())
        let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        return allCaffeine
            .filter { $0.dayStart >= day && $0.dayStart < next }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var totalMg: Double {
        todayDrinks.compactMap(\.caffeineMg).reduce(0, +)
    }

    private var limitMg: Double {
        profile?.caffeineLimitMg ?? 400
    }

    private var fillRatio: CGFloat {
        guard limitMg > 0 else { return 0 }
        return min(1.2, CGFloat(totalMg / limitMg))
    }

    private static let presets: [(label: String, mg: Double)] = [
        ("Coffee", 95),
        ("Espresso", 63),
        ("Tea", 47),
        ("Energy drink", 160),
    ]

    var body: some View {
        ModalSheetContainer(title: "Caffeine", onClose: { router.closeModal() }) {
            VStack(spacing: 18) {
                gauge
                quickAdds
                history
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private var gauge: some View {
        let intakeIndicators: [DialIndicator] = todayDrinks.prefix(20).map { drink in
            DialIndicator(
                angle: DialClock.angle(forHour: hour(of: drink.timestamp)),
                color: .biteCarbs,
                size: 11,
                inset: 12,
                systemImage: nil,
                glow: false
            )
        }

        let arc = DialArc(
            startAngle: 0,
            endAngle: 360 * Double(min(1.0, fillRatio)),
            color: arcStyle,
            width: 14,
            inset: 14
        )

        return VStack(spacing: 8) {
            OrbitDial(
                theme: .activity,
                arcs: [arc],
                indicators: intakeIndicators
            ) {
                VStack(spacing: 2) {
                    Text("\(Int(totalMg))")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.biteInk)
                        .contentTransition(.numericText())
                    Text("/ \(Int(limitMg)) mg")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.biteInkMuted)
                }
            }
            .frame(maxWidth: 240, maxHeight: 240)

            Text("\(Int((Double(fillRatio) * 100).rounded()))% of daily limit")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.biteInkMuted)
        }
        .padding(.top, 6)
    }

    private func hour(of date: Date) -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    private var arcStyle: Color {
        if fillRatio > 1.0 { return .biteRed }
        if fillRatio > 0.8 { return .biteWarning }
        return .biteCarbs
    }

    private var quickAdds: some View {
        VStack(spacing: 8) {
            ForEach(Self.presets, id: \.label) { preset in
                Button {
                    add(label: preset.label, mg: preset.mg)
                } label: {
                    HStack {
                        Text(preset.label)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.biteInk)
                        Spacer()
                        Text("+\(Int(preset.mg)) mg")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.biteCarbs)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.biteCarbs.opacity(0.10))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.biteCarbs.opacity(0.35), lineWidth: 1)
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

            if todayDrinks.isEmpty {
                Text("No caffeine logged yet today.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
                    .padding(.vertical, 8)
            } else {
                ForEach(todayDrinks) { drink in
                    HStack(spacing: 10) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.biteCarbs)
                        Text(drink.timestamp, format: .dateTime.hour().minute())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.biteInkMuted)
                            .frame(width: 60, alignment: .leading)
                        Text(drink.label ?? "Caffeine")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.biteInk)
                        Spacer()
                        Text("\(Int(drink.caffeineMg ?? 0)) mg")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.biteInk)
                        Button(role: .destructive) {
                            modelContext.delete(drink)
                            try? modelContext.save()
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

    private func add(label: String, mg: Double) {
        let entry = SDDrinkEntry(kind: .caffeine, caffeineMg: mg, label: label)
        modelContext.insert(entry)
        try? modelContext.save()
    }
}
