import Foundation
import SwiftUI

@MainActor
@Observable
final class AnalyticsViewModel {
    var selectedWeekOffset: Int = 0
    var selectedTab: AnalyticsTab = .stats
    var allLogs: [DayLog] = []

    enum AnalyticsTab: String, CaseIterable {
        case stats = "Statistiche"
        case streaks = "Streaks"
    }

    private let storage = StorageService.shared
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.locale = Locale(identifier: "it_IT")
        return cal
    }()

    // MARK: - Week Navigation

    var weekStartDate: Date {
        let today = calendar.startOfDay(for: Date())
        guard let shifted = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: today),
              let weekStart = calendar.dateInterval(of: .weekOfYear, for: shifted)?.start else {
            return today
        }
        return weekStart
    }

    var weekEndDate: Date {
        calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
    }

    var weekLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "it_IT")
        fmt.dateFormat = "d MMM"
        let start = fmt.string(from: weekStartDate)
        let end = fmt.string(from: weekEndDate)
        return "\(start) - \(end)"
    }

    var isCurrentWeek: Bool { selectedWeekOffset == 0 }

    // MARK: - Weekly Data

    var weekDayLogs: [DayLog?] {
        (0..<7).map { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) else { return nil }
            let log = allLogs.first { calendar.isDate($0.date, inSameDayAs: date) }
            if let log, !log.entries.isEmpty { return log }
            return nil
        }
    }

    var dayLabels: [String] { ["L", "M", "M", "G", "V", "S", "D"] }

    func isDayToday(_ index: Int) -> Bool {
        guard let date = calendar.date(byAdding: .day, value: index, to: weekStartDate) else { return false }
        return calendar.isDateInToday(date)
    }

    func isDayFuture(_ index: Int) -> Bool {
        guard let date = calendar.date(byAdding: .day, value: index, to: weekStartDate) else { return false }
        return date > Date()
    }

    // MARK: - Averages

    private var logsWithData: [DayLog] {
        weekDayLogs.compactMap { $0 }
    }

    var avgCalories: Int {
        let logs = logsWithData
        guard !logs.isEmpty else { return 0 }
        return logs.map(\.totalCalories).reduce(0, +) / logs.count
    }

    var avgProtein: Double {
        let logs = logsWithData
        guard !logs.isEmpty else { return 0 }
        return logs.map(\.totalProtein).reduce(0, +) / Double(logs.count)
    }

    var avgCarbs: Double {
        let logs = logsWithData
        guard !logs.isEmpty else { return 0 }
        return logs.map(\.totalCarbs).reduce(0, +) / Double(logs.count)
    }

    var avgFat: Double {
        let logs = logsWithData
        guard !logs.isEmpty else { return 0 }
        return logs.map(\.totalFat).reduce(0, +) / Double(logs.count)
    }

    // MARK: - Streaks

    var currentStreak: Int {
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        while true {
            let hasLog = allLogs.contains { log in
                calendar.isDate(log.date, inSameDayAs: checkDate) && !log.entries.isEmpty
            }
            if hasLog {
                streak += 1
            } else if !calendar.isDateInToday(checkDate) {
                break
            } else {
                // Today without log doesn't break streak, check yesterday
                // but don't count today
            }

            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            if !hasLog && calendar.isDateInToday(checkDate) {
                checkDate = prev
                continue
            }
            checkDate = prev
        }
        return streak
    }

    var longestStreak: Int {
        let sortedDates = allLogs
            .filter { !$0.entries.isEmpty }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        guard !sortedDates.isEmpty else { return 0 }

        var maxStreak = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i - 1], to: sortedDates[i]).day ?? 0
            if diff == 1 {
                current += 1
                maxStreak = max(maxStreak, current)
            } else if diff > 1 {
                current = 1
            }
            // diff == 0 means same day, skip
        }
        return maxStreak
    }

    // MARK: - Calendar (Streaks tab)

    var currentMonthDate: Date {
        Date()
    }

    var currentMonthName: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "it_IT")
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: currentMonthDate).capitalized
    }

    var daysInCurrentMonth: Int {
        calendar.range(of: .day, in: .month, for: currentMonthDate)?.count ?? 30
    }

    var firstWeekdayOfMonth: Int {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonthDate)) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        // Convert to Monday-based (Mon=0, Tue=1, ..., Sun=6)
        return (weekday + 5) % 7
    }

    var monthDaysWithLogs: Set<Int> {
        let comps = calendar.dateComponents([.year, .month], from: currentMonthDate)
        var days = Set<Int>()
        for log in allLogs where !log.entries.isEmpty {
            let logComps = calendar.dateComponents([.year, .month, .day], from: log.date)
            if logComps.year == comps.year && logComps.month == comps.month, let day = logComps.day {
                days.insert(day)
            }
        }
        return days
    }

    var todayDay: Int {
        calendar.component(.day, from: Date())
    }

    // MARK: - Monthly Calorie Data

    var monthlyCalorieData: [(date: Date, calories: Int)] {
        let today = calendar.startOfDay(for: Date())
        return (0..<30).reversed().compactMap { offset -> (date: Date, calories: Int)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let log = allLogs.first { calendar.isDate($0.date, inSameDayAs: date) }
            let calories = log?.totalCalories ?? 0
            guard calories > 0 else { return nil }
            return (date: date, calories: calories)
        }
    }

    // MARK: - Actions

    func changeWeek(by offset: Int) {
        selectedWeekOffset += offset
    }

    func loadData() {
        allLogs = storage.loadAllLogs()
    }
}
