import SwiftUI

extension View {
    @ViewBuilder
    func biteGlassCapsule() -> some View {
        self.glassEffect(in: .capsule)
    }

    @ViewBuilder
    func biteGlassRect(cornerRadius: CGFloat) -> some View {
        self.glassEffect(in: .rect(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func biteGlass<S: Shape>(in shape: S) -> some View {
        self.glassEffect(in: shape)
    }
}
