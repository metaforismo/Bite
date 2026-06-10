import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum BiteMotion {
    static let routeSheet      = Animation.timingCurve(0.2, 0.85, 0.25, 1.0, duration: 0.42)
    static let homePushBack    = Animation.timingCurve(0.2, 0.7,  0.2,  1.0, duration: 0.40)
    static let drawerSlide     = Animation.timingCurve(0.2, 0.7,  0.2,  1.0, duration: 0.32)
    static let scrimFade       = Animation.linear(duration: 0.28)
    static let plusSheet       = Animation.timingCurve(0.2, 0.9,  0.3,  1.1, duration: 0.36)
    static let bubbleRise      = Animation.timingCurve(0.2, 0.7,  0.2,  1.0, duration: 0.32)
    static let thinkingRise    = Animation.easeOut(duration: 0.28)
    static let countPop        = Animation.easeOut(duration: 0.50)
    static let ringDraw        = Animation.timingCurve(0.2, 0.7,  0.2,  1.0, duration: 1.20)
    static let chartDraw       = Animation.timingCurve(0.2, 0.7,  0.2,  1.0, duration: 0.70)

    static let orbBreathe      = Animation.easeInOut(duration: 4.2).repeatForever(autoreverses: true)
    static let orbBreatheFast  = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let orbPulse        = Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true)
    static let orbPulseSlow    = Animation.easeInOut(duration: 4.2).repeatForever(autoreverses: true)
    static let waveBar         = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)

    // V2 onboarding motion — refined for quicker, more responsive feel.
    static let onboardingPage  = Animation.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0)
    static let onboardingHero  = Animation.spring(response: 0.55, dampingFraction: 0.72, blendDuration: 0)
    static let onboardingTitle = Animation.spring(response: 0.50, dampingFraction: 0.80, blendDuration: 0)
    static let onboardingCTA   = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0)
    static let chipSelect      = Animation.spring(response: 0.28, dampingFraction: 0.72, blendDuration: 0)
    static let progressBar     = Animation.spring(response: 0.55, dampingFraction: 0.85, blendDuration: 0)

    /// Chat morph timing — used by `BiteShell` when transitioning to/from
    /// the chat route. Response 0.45s lets the composer's geometry expand
    /// from the home pill (~50pt tall) to the full-width chat composer
    /// readably; damping 0.82 prevents the perceived bounce that 0.7
    /// would introduce on an element this prominent.
    static let chatMorph       = Animation.spring(response: 0.62, dampingFraction: 0.88, blendDuration: 0.04)
}

/// Lightweight haptic helper used by selection chips, page advances, and the
/// completion CTA. Wrap in a static method so calls stay one-liners.
enum BiteHaptics {
    @MainActor static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    @MainActor static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    @MainActor static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
