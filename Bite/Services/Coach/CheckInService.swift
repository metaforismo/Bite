import Foundation
import SwiftData
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Thin wrapper around AlarmKit (iOS 26+). Each scheduled check-in produces a
/// `CheckInSchedule` row that survives across launches. When AlarmKit isn't
/// available (simulator + non-iOS-26 contexts), the service degrades to UNNotification
/// so check-ins still fire.
@MainActor
final class CheckInService {
    static let shared = CheckInService()
    private init() {}

    func schedule(prompt: String, cadence: String, fireAt: Date, in context: ModelContext) async throws -> CheckInSchedule {
        let row = CheckInSchedule(prompt: prompt, cadence: cadence, nextFireAt: fireAt)
        context.insert(row)
        try context.save()

        // AlarmKit wiring lands once the user enables the AlarmKit capability in the project.
        // Until then, we fall back to UNUserNotificationCenter via the existing NotificationService.
        NotificationService.shared.scheduleReminderIfNeeded()

        return row
    }

    func cancel(_ schedule: CheckInSchedule, in context: ModelContext) async {
        context.delete(schedule)
        try? context.save()
    }

    // MARK: - Smart Sleep Alarm

    /// Schedule N candidate alarms 5 minutes apart in the wake window
    /// `[target − windowMinutes, target]`. Each fires with a UNNotification at
    /// its time; once the first candidate fires, the app's notification
    /// delegate (`AppDelegate`) cancels the remaining pending candidates so
    /// only one alarm wakes the user. Returns the persisted SDSmartAlarm row.
    func scheduleSmartAlarm(
        targetHour: Int,
        targetMinute: Int,
        windowMinutes: Int,
        hapticIntensity: AlarmHapticIntensity,
        savedToWatch: Bool,
        in context: ModelContext
    ) async throws -> SDSmartAlarm {
        // 1) Cancel any prior smart alarms.
        let existing = try context.fetch(FetchDescriptor<SDSmartAlarm>())
        for row in existing {
            await cancelSmartAlarm(row, in: context)
        }

        // 2) Authorize notifications if needed.
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])

        // 3) Compute candidate fire offsets (5 minutes apart, deadline included).
        let stride = 5
        let count = max(1, windowMinutes / stride + 1)
        var candidateIDs: [UUID] = []
        for i in 0..<count {
            let offset = -windowMinutes + i * stride
            var comps = DateComponents()
            comps.hour = targetHour
            comps.minute = targetMinute + offset
            // Calendar normalizes negative minutes into the previous hour.
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let id = UUID()
            candidateIDs.append(id)

            let content = UNMutableNotificationContent()
            content.title = "Smart Alarm"
            content.body = i == count - 1 ? "Wake up — final alarm." : "Light sleep window — easy wake."
            content.sound = .default
            content.userInfo = [
                "kind": "smart_alarm_candidate",
                "windowOffsetMinutes": offset,
                "hapticIntensity": hapticIntensity.rawValue,
                "isDeadline": i == count - 1,
            ]

            let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)
            try? await center.add(request)
        }

        // 4) Persist the alarm row with candidate IDs.
        let row = SDSmartAlarm(
            targetHour: targetHour,
            targetMinute: targetMinute,
            windowMinutes: windowMinutes,
            hapticIntensity: hapticIntensity,
            savedToWatch: savedToWatch,
            enabled: true,
            candidateAlarmIDs: candidateIDs
        )
        context.insert(row)
        try context.save()
        return row
    }

    func cancelSmartAlarm(_ alarm: SDSmartAlarm, in context: ModelContext) async {
        let ids = alarm.candidateAlarmIDs.map(\.uuidString)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        context.delete(alarm)
        try? context.save()
    }
}
