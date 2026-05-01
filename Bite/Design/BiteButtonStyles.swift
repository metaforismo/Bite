import SwiftUI

/// Three-tier button style system replacing scattered ad-hoc capsules.
/// All variants ship with `BiteHaptics.impact(.light)` on press so every
/// button feel matches the rest of the chrome.

enum BiteButtonSize {
    case small, regular, large

    var verticalPadding: CGFloat {
        switch self {
        case .small:   return 7
        case .regular: return 11
        case .large:   return 14
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small:   return 12
        case .regular: return 18
        case .large:   return 24
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small:   return 12
        case .regular: return 13
        case .large:   return 15
        }
    }
}

struct BitePrimaryButtonStyle: ButtonStyle {
    var size: BiteButtonSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: .infinity)
            .background(.biteInk, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { BiteHaptics.impact(.light) }
            }
    }
}

struct BiteSecondaryButtonStyle: ButtonStyle {
    var size: BiteButtonSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .bold))
            .foregroundStyle(.biteInk)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { BiteHaptics.impact(.light) }
            }
    }
}

struct BiteGhostButtonStyle: ButtonStyle {
    var size: BiteButtonSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold))
            .foregroundStyle(.biteInkMuted)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { BiteHaptics.impact(.light) }
            }
    }
}
