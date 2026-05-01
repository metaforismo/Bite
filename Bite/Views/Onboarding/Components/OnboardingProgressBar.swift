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
            GeometryReader { geo in
                let fillWidth = max(0, geo.size.width * progress)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.07))
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.biteRed, Color.biteRedSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 4)
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .shadow(color: Color.biteRed.opacity(0.4), radius: 4, x: 0, y: 0)
                                .opacity(progress > 0 ? 1 : 0)
                        }
                        .animation(BiteMotion.progressBar, value: progress)
                }
            }
            .frame(height: 8)
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
