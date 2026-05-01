import SwiftUI

struct FloatingPillButton<Leading: View, Label: View>: View {
    let leading: Leading
    let label: Label
    let action: () -> Void

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder label: () -> Label, action: @escaping () -> Void) {
        self.leading = leading()
        self.label = label()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leading
                label
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(Color.white.opacity(0.92), in: Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 6)
            .biteGlassCapsule()
        }
        .buttonStyle(.plain)
    }
}
