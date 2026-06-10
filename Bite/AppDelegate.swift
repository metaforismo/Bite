import SwiftUI
import UserNotifications

/// Shared bridge between the notification delegate and SwiftUI: the delegate
/// stages a deep link here and `BiteApp` forwards it to `pendingDeepLink`.
@MainActor
@Observable
final class DeepLinkBox {
    static let shared = DeepLinkBox()
    var pending: BiteDeepLink?

    private init() {}
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        cancelRemainingSmartAlarmCandidates(after: notification)
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        cancelRemainingSmartAlarmCandidates(after: response.notification)

        if response.notification.request.content.userInfo["deep_link"] as? String == "daily_review" {
            Task { @MainActor in
                DeepLinkBox.shared.pending = .dailyReview
            }
        }
        completionHandler()
    }

    nonisolated private func cancelRemainingSmartAlarmCandidates(after notification: UNNotification) {
        guard notification.request.content.userInfo["kind"] as? String == "smart_alarm_candidate" else { return }
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let candidateIDs = requests
                .filter { $0.content.userInfo["kind"] as? String == "smart_alarm_candidate" }
                .map(\.identifier)
            guard !candidateIDs.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: candidateIDs)
        }
    }
}
