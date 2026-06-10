import SwiftUI

/// Long-press a card to surface an "Ask Bite" pill that opens the Coach
/// pre-filled with a contextual prompt. Lets every insight on the home
/// tabs become a chat starter — fundamental to the "Coach as command
/// center" model.
extension View {
    /// Attach to any card or row to make it long-press-actionable.
    /// `prefill` is the prompt text the chat composer opens with.
    func askCoachContext(_ prefill: String) -> some View {
        modifier(AskCoachContextModifier(prefill: prefill))
    }
}

private struct AskCoachContextModifier: ViewModifier {
    let prefill: String
    @Environment(BiteRouter.self) private var router
    @State private var pillVisible: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if pillVisible {
                    AskCoachPill {
                        BiteHaptics.impact(.light)
                        pillVisible = false
                        router.openChat(prefill: prefill)
                    }
                    .padding(8)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .onLongPressGesture(minimumDuration: 0.32, maximumDistance: 24) {
                BiteHaptics.impact(.medium)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    pillVisible = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeOut(duration: 0.25)) {
                        pillVisible = false
                    }
                }
            }
    }
}

private struct AskCoachPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .heavy))
                Text("Ask Bite")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.biteInk, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
