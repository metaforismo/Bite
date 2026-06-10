import SwiftUI
import AVFoundation

struct MicrophonePermissionView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var hasResolved = false

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Microphone",
            iconColor: .biteBlue,
            title: "Enable microphone",
            subtitle: "Log meals and chat with Coach using your voice — fastest way to track on the go.",
            primaryActionTitle: isRequesting ? "Requesting…" : (hasResolved ? "Continue" : "Enable microphone"),
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
            AVAudioApplication.requestRecordPermission { _ in
                Task { @MainActor in
                    isRequesting = false
                    hasResolved = true
                }
            }
        }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .today)
        MicrophonePermissionView(onContinue: {})
    }
}
