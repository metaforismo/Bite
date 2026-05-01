import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleReminderIfNeeded() {
        let center = UNUserNotificationCenter.current()

        // Remove existing reminders
        center.removePendingNotificationRequests(withIdentifiers: ["bite_daily_reminder"])

        // Check if user has logged today
        let todayLog = StorageService.shared.loadDayLog(for: Date())
        guard todayLog.entries.isEmpty else { return }

        // Schedule for 8 PM
        let content = UNMutableNotificationContent()
        content.title = "Bite"
        content.body = "Non hai ancora registrato nulla oggi"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "bite_daily_reminder", content: content, trigger: trigger)

        center.add(request)
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bite_daily_reminder"])
    }
}
