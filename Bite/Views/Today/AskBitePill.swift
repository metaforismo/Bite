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
    @State private var breathing = false

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
                Image(systemName: "mic")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.biteInkMuted)
                    .frame(width: 24, height: 24)
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.biteInk, in: Circle())
            }
            .padding(8)
        }
        .buttonStyle(PressableScaleButtonStyle())
        .background {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            Color.biteRedTint.opacity(breathing ? 0.70 : 0.48),
                            Color.white.opacity(0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.86), lineWidth: 1)
                .overlay(
                    Capsule()
                        .stroke(Color.biteRed.opacity(breathing ? 0.16 : 0.06), lineWidth: 1)
                )
        }
        .shadow(color: Color.biteRed.opacity(breathing ? 0.18 : 0.10), radius: breathing ? 30 : 22, x: 0, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 5)
        .glassEffect(in: .capsule)
        .matchedGeometryEffect(id: "composer", in: morphNS)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}
