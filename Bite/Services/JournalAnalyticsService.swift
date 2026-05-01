import Foundation

/// Local-data analytics over the user's `DayLog` history.
///
/// Phase 2 wires this into `JournalView` charts; for Phase 1 it exists so
/// deleting `AnalyticsViewModel` doesn't lose the aggregation logic.
@MainActor
struct JournalAnalyticsService {
    var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    func weekStartDate(weekOffset: Int, reference: Date = .now) -> Date {
        let today = calendar.startOfDay(for: reference)
        guard let shifted = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: today),
              let weekStart = calendar.dateInterval(of: .weekOfYear, for: shifted)?.start else {
            return today
        }
        return weekStart
    }

    func weekEndDate(weekOffset: Int, reference: Date = .now) -> Date {
        let start = weekStartDate(weekOffset: weekOffset, reference: reference)
        return calendar.date(byAdding: .day, value: 6, to: start) ?? start
    }

    func weekDayLogs(in logs: [DayLog], weekOffset: Int, reference: Date = .now) -> [DayLog?] {
        let start = weekStartDate(weekOffset: weekOffset, reference: reference)
        return (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: date) }
            return (log?.entries.isEmpty == false) ? log : nil
        }
    }

    func averages(in logs: [DayLog], weekOffset: Int, reference: Date = .now) -> WeeklyAverages {
        let active = weekDayLogs(in: logs, weekOffset: weekOffset, reference: reference).compactMap { $0 }
        guard !active.isEmpty else { return .zero }
        let count = Double(active.count)
        return WeeklyAverages(
            calories: active.map(\.totalCalories).reduce(0, +) / active.count,
            protein: active.map(\.totalProtein).reduce(0, +) / count,
            carbs: active.map(\.totalCarbs).reduce(0, +) / count,
            fat: active.map(\.totalFat).reduce(0, +) / count
        )
    }

    func currentStreak(in logs: [DayLog], reference: Date = .now) -> Int {
        let today = calendar.startOfDay(for: reference)
        var streak = 0
        var checkDate = today

        while true {
            let hasLog = logs.contains { log in
                calendar.isDate(log.date, inSameDayAs: checkDate) && !log.entries.isEmpty
            }
            if hasLog {
                streak += 1
            } else if !calendar.isDate(checkDate, inSameDayAs: today) {
                break
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    func longestStreak(in logs: [DayLog]) -> Int {
        let sorted = logs
            .filter { !$0.entries.isEmpty }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
        guard !sorted.isEmpty else { return 0 }

        var maxStreak = 1
        var current = 1
        for i in 1..<sorted.count {
            let diff = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if diff == 1 {
                current += 1
                maxStreak = max(maxStreak, current)
            } else if diff > 1 {
                current = 1
            }
        }
        return maxStreak
    }

    func monthDaysWithLogs(in logs: [DayLog], reference: Date = .now) -> Set<Int> {
        let comps = calendar.dateComponents([.year, .month], from: reference)
        var days = Set<Int>()
        for log in logs where !log.entries.isEmpty {
            let logComps = calendar.dateComponents([.year, .month, .day], from: log.date)
            if logComps.year == comps.year, logComps.month == comps.month, let day = logComps.day {
                days.insert(day)
            }
        }
        return days
    }

    func monthlyCalorieTrend(in logs: [DayLog], days: Int = 30, reference: Date = .now) -> [DailyCalorieSample] {
        let today = calendar.startOfDay(for: reference)
        return (0..<days).reversed().compactMap { offset -> DailyCalorieSample? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: date) }
            let calories = log?.totalCalories ?? 0
            guard calories > 0 else { return nil }
            return DailyCalorieSample(date: date, calories: calories)
        }
    }
}

struct WeeklyAverages: Equatable {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    static let zero = WeeklyAverages(calories: 0, protein: 0, carbs: 0, fat: 0)
}

struct DailyCalorieSample: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let calories: Int
}
