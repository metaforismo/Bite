import SwiftUI

/// Two-state floating pill on Today.
///
/// **Collapsed**: a glass capsule with a micro-orb + "Ask Bite anything" placeholder.
/// Tapping focuses the inline TextField, the keyboard rises, and the pill expands.
///
/// **Expanded**: a docked composer above the keyboard with a horizontal chip
/// carousel of quick actions, a leading + button (opens PlusSheet), an inline
/// TextField, and a trailing send button. Submitting routes the typed query
/// straight into Coach as a pre-filled prompt.
///
/// The collapsed → expanded → Coach-composer morph reuses one `glassEffectID`
/// in the parent `morphNS` namespace so the geometry feels like one element.
struct AskBitePill: View {
    @Bindable var router: BiteRouter
    let morphNS: Namespace.ID

    @State private var query: String = ""
    @State private var isExpanded: Bool = false
    @FocusState private var focused: Bool

    private static let chips: [(label: String, prefill: String)] = [
        ("Predictive modeling", "Forecast my recovery for the next 7 days."),
        ("Log food", "Help me log a meal."),
        ("Analyze labs", "Walk me through my latest lab results."),
        ("Symptom check", "I've been feeling off — let's run through a symptom check."),
        ("New training plan", "Build me a new training plan."),
        ("Goal setting", "Help me set a new goal."),
    ]

    var body: some View {
        Group {
            if isExpanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isExpanded)
    }

    private var collapsedView: some View {
        Button {
            BiteHaptics.impact(.light)
            isExpanded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
            }
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

    private var expandedView: some View {
        VStack(spacing: 8) {
            chipCarousel
            composerRow
        }
    }

    private var chipCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.chips, id: \.label) { chip in
                    Button {
                        submit(prefill: chip.prefill)
                    } label: {
                        Text(chip.label)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.biteInk)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.92)))
                            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var composerRow: some View {
        HStack(spacing: 10) {
            Button {
                router.openPlusSheet()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.biteInk)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.05)))
            }
            .buttonStyle(.plain)

            TextField("Ask Bite anything", text: $query)
                .font(.system(size: 14.5, weight: .medium))
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { submitTyped() }

            Button {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    collapse()
                } else {
                    submitTyped()
                }
            } label: {
                Image(systemName: query.isEmpty ? "xmark" : "arrow.up")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(query.isEmpty ? Color.black.opacity(0.25) : Color.biteRed)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 4)
        .glassEffect(in: .capsule)
        .matchedGeometryEffect(id: "composer", in: morphNS)
    }

    private func submitTyped() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        submit(prefill: text)
    }

    private func submit(prefill: String) {
        query = ""
        focused = false
        isExpanded = false
        router.openChat(prefill: prefill)
    }

    private func collapse() {
        focused = false
        isExpanded = false
    }
}

