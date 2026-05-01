import SwiftUI

/// Floating pill on Today. Shows a micro orb + "Ask Bite anything"
/// placeholder. Tap → opens `CoachView` directly via the chat route.
///
/// Pairs with `CoachView`'s composer through `matchedGeometryEffect(id:
/// "composer", in: morphNS)` so SwiftUI animates a single element morph
/// from this pill into the full-width Coach composer when the user taps.
struct AskBitePill: View {
    @Bindable var router: BiteRouter
    let morphNS: Namespace.ID

    var body: some View {
        Button {
            BiteHaptics.impact(.light)
            router.openChat(prefill: nil)
        } label: {
            HStack(spacing: 10) {
                BiteOrbImage(size: 24, mood: .neutral, state: .idle, showHalo: false)
                Text("Ask Bite anything")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(.biteInkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
        }
        .buttonStyle(PressableScaleButtonStyle())
        .background(Color.white.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 6)
        .glassEffect(in: .capsule)
        .matchedGeometryEffect(id: "composer", in: morphNS)
    }
}
