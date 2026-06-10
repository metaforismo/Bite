import SwiftUI

/// Continuous capsule progress indicator. Sits inside `BiteTopBar`'s trailing
/// slot; shares the row with the back button. Hidden on the welcome page
/// (`current == 0`) — the parent row keeps its 56pt height regardless so
/// pages don't shift when the bar appears.
struct OnboardingProgressBar: View {
    let totalPages: Int
    let currentPage: Int

    private var progress: CGFloat {
        guard totalPages > 1 else { return 0 }
        return CGFloat(currentPage) / CGFloat(totalPages - 1)
    }

    var body: some View {
        if currentPage > 0 {
            let segments = max(totalPages - 1, 1)
            HStack(spacing: 3) {
                ForEach(0..<segments, id: \.self) { index in
                    Capsule()
                        .fill(index < currentPage ? Color.biteRed : Color.black.opacity(0.08))
                        .frame(height: 5)
                        .animation(BiteMotion.progressBar.delay(Double(index) * 0.006), value: currentPage)
                }
            }
            .frame(height: 10)
            .accessibilityLabel("Onboarding progress")
            .accessibilityValue("\(Int(progress * 100)) percent")
        }
    }
}

#Preview {
    ZStack {
        Color(hex: 0xFFF6F2)
        VStack(spacing: 24) {
            OnboardingProgressBar(totalPages: 22, currentPage: 0)
            OnboardingProgressBar(totalPages: 22, currentPage: 1)
            OnboardingProgressBar(totalPages: 22, currentPage: 11)
            OnboardingProgressBar(totalPages: 22, currentPage: 22)
        }
        .padding()
    }
}
