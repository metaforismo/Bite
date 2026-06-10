import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    private static let dailyReminderId = "bite_daily_reminder"
    private static let dailyReviewId = "bite_daily_review"

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// Reminds at 8pm if no food has been logged today.
    func scheduleReminderIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderId])

        let todayLog = StorageService.shared.loadDayLog(for: Date())
        guard todayLog.entries.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Bite"
        content.body = "You haven't logged anything today — open Bite to catch up?"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: Self.dailyReminderId, content: content, trigger: trigger)
        center.add(request)
    }

    /// Recurring 9pm "Daily review with Bite" prompt. Tap opens the app
    /// at the chat with a prefilled review prompt (handled by deep-link
    /// resolver). Repeats every day until cancelled.
    func scheduleDailyReview() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReviewId])

        let content = UNMutableNotificationContent()
        content.title = "Daily review with Bite"
        content.body = "How did today go? Tap to walk through it together."
        content.sound = .default
        content.userInfo = ["deep_link": "daily_review"]

        var components = DateComponents()
        components.hour = 21
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.dailyReviewId, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelDailyReview() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyReviewId])
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderId])
    }
}
