import SwiftUI
import AVFoundation

struct CameraPermissionView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingScaffold(
            iconImageName: "Camera",
            iconColor: .bitePurple,
            title: "Enable camera",
            subtitle: "Snap a meal — Bite analyzes the photo and logs it automatically.",
            primaryActionTitle: isRequesting ? "Requesting…" : "Enable camera",
            primaryActionLoading: isRequesting,
            secondaryActionTitle: "Skip",
            secondaryAction: onContinue
        ) {
            EmptyView()
        } primaryAction: {
            isRequesting = true
            AVCaptureDevice.requestAccess(for: .video) { _ in
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
        CameraPermissionView(onContinue: {})
    }
}
