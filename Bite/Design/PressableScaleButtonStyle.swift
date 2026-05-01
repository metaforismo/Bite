import SwiftUI

/// Generic plain-background pressable style — adds a subtle scale + opacity
/// dip on press without altering the label visuals. Use anywhere a button
/// should feel physical (Today cards, status pill, modal handles).
struct PressableScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    var pressedOpacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
