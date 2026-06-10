import SwiftUI
import AVFoundation

struct CameraPermissionView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var hasResolved = false

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Camera",
            iconColor: .bitePurple,
            title: "Enable camera",
            subtitle: "Snap a meal — Bite analyzes the photo and logs it automatically.",
            primaryActionTitle: isRequesting ? "Requesting…" : (hasResolved ? "Continue" : "Enable camera"),
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
            AVCaptureDevice.requestAccess(for: .video) { _ in
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
        CameraPermissionView(onContinue: {})
    }
}
