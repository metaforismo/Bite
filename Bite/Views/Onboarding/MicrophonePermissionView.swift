import SwiftUI
import AVFoundation

struct MicrophonePermissionView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Microphone",
            iconColor: .biteBlue,
            title: "Enable microphone",
            subtitle: "Log meals and chat with Coach using your voice — fastest way to track on the go.",
            primaryActionTitle: isRequesting ? "Requesting…" : "Enable microphone",
            primaryActionLoading: isRequesting,
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            EmptyView()
        } primaryAction: {
            isRequesting = true
            AVAudioApplication.requestRecordPermission { _ in
                Task { @MainActor in
                    isRequesting = false
                    onContinue()
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
