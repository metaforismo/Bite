import SwiftUI

/// Renders the Bite mascot ("biteorbs.png" — a glassy bitten apple with eyes)
/// with an optional radial halo, breathing scale, and a subtle hover offset
/// to keep it feeling alive without swapping per-state assets.
///
/// The image itself is static; expressiveness is communicated through halo
/// intensity (mood) and breathe/pulse cadence (state). This keeps the bundle
/// asset-light while leaving the door open to a Rive-driven multi-state
/// version in the future — call sites won't change.
struct BiteOrbImage: View {
    var size: CGFloat = 130
    var mood: OrbMood = .neutral
    var state: OrbState = .idle
    var showHalo: Bool = true

    @State private var breathScale: CGFloat = 1.0
    @State private var hover: CGFloat = 0
    @State private var glowBrightness: Double = 1.0

    var body: some View {
        let palette = OrbPalette.palette(for: mood)
        ZStack {
            if showHalo {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                palette.glow.opacity(0.55),
                                palette.glow.opacity(0.25),
                                .clear
                            ]),
                            center: UnitPoint(x: 0.5, y: 0.55),
                            startRadius: 0,
                            endRadius: size * 0.85
                        )
                    )
                    .frame(width: size * 1.7, height: size * 1.7)
                    .blur(radius: 8)
                    .brightness(glowBrightness - 1.0)
            }

            Image("BiteOrbs")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        }
        .scaleEffect(breathScale)
        .offset(y: hover)
        .onAppear { startAnimating() }
        .onChange(of: state) { _, _ in startAnimating() }
    }

    private func startAnimating() {
        breathScale = 1.0
        hover = 0
        glowBrightness = 1.0

        let breath: Animation = state == .idle ? BiteMotion.orbBreathe : BiteMotion.orbBreatheFast
        withAnimation(breath) {
            breathScale = 1.025
            hover = -4
        }
        if showHalo {
            let pulse: Animation = (state == .thinking || state == .listening)
                ? BiteMotion.orbPulse
                : BiteMotion.orbPulseSlow
            withAnimation(pulse) {
                glowBrightness = 1.06
            }
        }
    }
}

#Preview {
    ZStack {
        BiteGradientBackground(style: .coach)
        VStack(spacing: 32) {
            BiteOrbImage(size: 130, mood: .neutral, state: .idle)
            BiteOrbImage(size: 32, mood: .neutral, state: .idle, showHalo: false)
        }
    }
}
