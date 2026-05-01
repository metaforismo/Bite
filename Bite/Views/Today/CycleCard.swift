import SwiftUI
import SwiftData

/// Cycle card on Today — visible only when `SDUserProfile.cycleTrackingEnabled`.
/// Shows a 28-day calendar strip (period days get a pink dashed ring), a phase
/// indicator, and the most recent AI-generated cycle insight (cached locally —
/// the user generates fresh insights via the Coach prompt).
struct CycleCard: View {
    @Query(sort: [SortDescriptor(\SDCycleEntry.date, order: .reverse)])
    private var entries: [SDCycleEntry]

    let onLogTap: () -> Void
    let onAskBite: () -> Void

    private var estimate: CyclePhaseEstimator.Estimate? {
        CyclePhaseEstimator.estimate(from: entries)
    }

    private var calendarDays: [(date: Date, isPeriod: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let entryByDate: [Date: SDCycleEntry] = Dictionary(uniqueKeysWithValues:
            entries.map { ($0.date, $0) }
        )
        return (0..<28).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, entryByDate[day]?.hasFlow == true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            calendarStrip
            phaseLine
            insightLine
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }

    private var header: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.biteRedSoft)
            Text("CYCLE")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            Spacer()
            Button(action: onLogTap) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.biteRedSoft)
            }
            .buttonStyle(.plain)
        }
    }

    private var calendarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, item in
                    CalendarDayChip(
                        date: item.date,
                        isPeriod: item.isPeriod,
                        isToday: Calendar.current.isDateInToday(item.date)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var phaseLine: some View {
        if let estimate {
            HStack(spacing: 6) {
                Text(estimate.phase.emoji).font(.system(size: 14))
                Text(phaseLabel(estimate))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.biteInk)
                if estimate.isLowConfidence {
                    Text("Low confidence")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(.biteInkMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.biteWarning.opacity(0.15))
                        )
                }
                Spacer()
            }
        } else {
            Text("Log a period to start phase tracking.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.biteInkMuted)
        }
    }

    private var insightLine: some View {
        Button(action: onAskBite) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text(estimate == nil ? "Ask Bite about cycle tracking" : "Ask Bite for a cycle insight")
                    .font(.system(size: 12.5, weight: .heavy))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                Spacer()
            }
            .foregroundStyle(.biteRed)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.biteRedTint, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func phaseLabel(_ e: CyclePhaseEstimator.Estimate) -> String {
        switch e.phase {
        case .menstrual:
            return "Day \(e.cycleDay) of period"
        default:
            return "\(e.phase.displayName) phase • Day \(e.cycleDay) of cycle"
        }
    }
}

private struct CalendarDayChip: View {
    let date: Date
    let isPeriod: Bool
    let isToday: Bool

    private var day: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private var weekday: String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(weekday)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.biteInkMuted)
            ZStack {
                if isToday {
                    Circle().fill(Color.biteRed)
                } else if isPeriod {
                    Circle()
                        .strokeBorder(
                            Color(hex: 0xFFB8C8),
                            style: StrokeStyle(lineWidth: 2, dash: [3, 2])
                        )
                }
                Text(day)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(isToday ? .white : .biteInk)
            }
            .frame(width: 32, height: 32)
        }
    }
}
