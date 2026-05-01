import Foundation

enum CyclePhase: String, CaseIterable, Sendable {
    case menstrual
    case follicular
    case ovulation
    case luteal

    var displayName: String {
        switch self {
        case .menstrual: return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulation: return "Ovulation"
        case .luteal: return "Luteal"
        }
    }

    var emoji: String {
        switch self {
        case .menstrual: return "🌑"
        case .follicular: return "🌒"
        case .ovulation: return "🌕"
        case .luteal: return "🌘"
        }
    }
}

/// Stateless estimator that derives the current cycle phase + day from a
/// chronologically sorted list of recent `SDCycleEntry` rows. Defaults to a
/// 28-day cycle when data is too thin (< 2 logged period starts).
enum CyclePhaseEstimator {
    struct Estimate {
        let phase: CyclePhase
        let cycleDay: Int
        let cycleLength: Int
        let lastPeriodStart: Date?
        /// True when the estimate is based on a single observed cycle or less
        /// — the UI should call out the lower confidence.
        let isLowConfidence: Bool
    }

    /// `entries` should be in date order. `now` is injected for testability.
    static func estimate(from entries: [SDCycleEntry], now: Date = Date()) -> Estimate? {
        let starts = periodStarts(from: entries)
        guard let lastStart = starts.last else { return nil }

        let length = inferCycleLength(starts: starts)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let daysSinceStart = max(0, (calendar.dateComponents([.day], from: lastStart, to: today).day ?? 0))
        let cycleDay = (daysSinceStart % length) + 1

        let phase: CyclePhase
        switch cycleDay {
        case 1...5:                              phase = .menstrual
        case 6...(length / 2 - 2):               phase = .follicular
        case (length / 2 - 1)...(length / 2 + 1): phase = .ovulation
        default:                                  phase = .luteal
        }

        return Estimate(
            phase: phase,
            cycleDay: cycleDay,
            cycleLength: length,
            lastPeriodStart: lastStart,
            isLowConfidence: starts.count < 2
        )
    }

    /// Days where flow > 0 and the previous day had no flow (period starts).
    private static func periodStarts(from entries: [SDCycleEntry]) -> [Date] {
        let sorted = entries.sorted { $0.date < $1.date }
        var starts: [Date] = []
        var previousHadFlow = false
        for entry in sorted {
            if entry.hasFlow && !previousHadFlow {
                starts.append(entry.date)
            }
            previousHadFlow = entry.hasFlow
        }
        return starts
    }

    private static func inferCycleLength(starts: [Date]) -> Int {
        guard starts.count >= 2 else { return 28 }
        let cal = Calendar.current
        var deltas: [Int] = []
        for i in 1..<starts.count {
            if let d = cal.dateComponents([.day], from: starts[i - 1], to: starts[i]).day, d > 14 {
                deltas.append(d)
            }
        }
        guard !deltas.isEmpty else { return 28 }
        let avg = Double(deltas.reduce(0, +)) / Double(deltas.count)
        // Clamp to a physiological 21–45 day window.
        return max(21, min(45, Int(avg.rounded())))
    }
}
