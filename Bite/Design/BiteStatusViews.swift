import SwiftUI

/// Three reusable templates for feedback states: empty, loading, error.
/// Each one accepts an optional custom-illustration name (one of the 32
/// PNGs in Assets.xcassets) so we can wire context-specific art per slot.

// MARK: - Empty state

struct BiteEmptyState: View {
    var illustrationName: String?
    var systemImage: String = "tray"
    var title: String
    var subtitle: String?
    var ctaLabel: String?
    var ctaAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Group {
                if let illustrationName, UIImage(named: illustrationName) != nil {
                    Image(illustrationName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.biteInkFaint)
                }
            }
            VStack(spacing: 4) {
                Text(title)
                    .biteFont(.headline)
                    .foregroundStyle(.biteInk)
                if let subtitle {
                    Text(subtitle)
                        .biteFont(.body)
                        .foregroundStyle(.biteInkFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            if let ctaLabel, let ctaAction {
                Button(ctaLabel, action: ctaAction)
                    .buttonStyle(BitePrimaryButtonStyle(size: .small))
                    .frame(maxWidth: 200)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Loading state (skeleton shimmer)

struct BiteLoadingState: View {
    enum Size { case small, regular, large
        var height: CGFloat {
            switch self { case .small: return 60; case .regular: return 120; case .large: return 200 }
        }
    }
    var size: Size = .regular

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .biteInkFaint.opacity(0.12),
                        .biteInkFaint.opacity(0.20),
                        .biteInkFaint.opacity(0.12),
                    ],
                    startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
                )
            )
            .frame(height: size.height)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

// MARK: - Error state

struct BiteErrorState: View {
    var title: String = "Something went wrong"
    var subtitle: String?
    var retryLabel: String = "Retry"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.biteRed.opacity(0.13))
                    .frame(width: 56, height: 56)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.biteRed)
            }
            VStack(spacing: 4) {
                Text(title)
                    .biteFont(.headline)
                    .foregroundStyle(.biteInk)
                if let subtitle {
                    Text(subtitle)
                        .biteFont(.body)
                        .foregroundStyle(.biteInkFaint)
                        .multilineTextAlignment(.center)
                }
            }
            if let retry {
                Button(retryLabel, action: retry)
                    .buttonStyle(BiteSecondaryButtonStyle(size: .small))
                    .frame(maxWidth: 160)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
