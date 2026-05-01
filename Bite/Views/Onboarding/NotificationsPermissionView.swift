import SwiftUI
import UserNotifications

struct NotificationsPermissionView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Notifications",
            iconColor: .biteOrange,
            title: "Enable notifications",
            subtitle: "Bite sends gentle reminders so you don't forget to log meals or check on your goals.",
            primaryActionTitle: isRequesting ? "Requesting…" : "Enable notifications",
            primaryActionLoading: isRequesting,
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            EmptyView()
        } primaryAction: {
            isRequesting = true
            Task {
                let center = UNUserNotificationCenter.current()
                _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
                isRequesting = false
                onContinue()
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
