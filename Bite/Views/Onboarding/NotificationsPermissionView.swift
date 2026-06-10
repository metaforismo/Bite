import SwiftUI
import UserNotifications

struct NotificationsPermissionView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var hasResolved = false

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Notifications",
            iconColor: .biteOrange,
            title: "Enable notifications",
            subtitle: "Bite sends gentle reminders so you don't forget to log meals or check on your goals.",
            primaryActionTitle: isRequesting ? "Requesting…" : (hasResolved ? "Continue" : "Enable notifications"),
            primaryActionLoading: isRequesting,
            primaryActionConfirmed: hasResolved,
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            EmptyView()
        } primaryAction: {
            if hasResolved {
                onContinue()
                return
            }
            isRequesting = true
            Task {
                let center = UNUserNotificationCenter.current()
                _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
                isRequesting = false
                hasResolved = true
            }
        }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        NotificationsPermissionView(onContinue: {})
    }
}
