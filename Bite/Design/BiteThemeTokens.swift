import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension ShapeStyle where Self == Color {
    static var biteRed: Color { Color(hex: 0xF43F3F) }
    static var biteRedSoft: Color { Color(hex: 0xFF7A7A) }
    static var biteRedTint: Color { Color(hex: 0xFFE8E8) }
    static var biteRedDeep: Color { Color(hex: 0xC72E2E) }
    static var biteBgWarm: Color { Color(hex: 0xFFF6F2) }
    static var biteBgCool: Color { Color(hex: 0xF0EEF6) }
    static var biteBgMint: Color { Color(hex: 0xECF5EE) }
    static var biteInk: Color { Color(hex: 0x161618) }
    static var biteInkMuted: Color { Color(hex: 0x6B6B72) }
    static var biteInkFaint: Color { Color(hex: 0xA8A8B0) }
    static var biteRingNutrition: Color { Color(hex: 0xF43F3F) }
    static var biteRingRecovery: Color { Color(hex: 0x2BB36A) }
    static var biteRingSleep: Color { Color(hex: 0x7C6BD9) }
    static var biteHydration: Color { Color(hex: 0x5BA8E5) }
    static var biteCarbs: Color { Color(hex: 0xF4A532) }
    static var biteFat: Color { Color(hex: 0x7C6BD9) }
    static var biteFiber: Color { Color(hex: 0x2BB36A) }
    static var biteWarning: Color { Color(hex: 0xF4A532) }
}

extension Color {
    static let biteRedSoft   = Color(hex: 0xFF7A7A)
    static let biteRedTint   = Color(hex: 0xFFE8E8)
    static let biteRedDeep   = Color(hex: 0xC72E2E)

    static let biteBgWarm    = Color(hex: 0xFFF6F2)
    static let biteBgCool    = Color(hex: 0xF0EEF6)
    static let biteBgMint    = Color(hex: 0xECF5EE)

    static let biteInk       = Color(hex: 0x161618)
    static let biteInkMuted  = Color(hex: 0x6B6B72)
    static let biteInkFaint  = Color(hex: 0xA8A8B0)

    static let biteLine      = Color.black.opacity(0.07)
    static let biteCard      = Color.white.opacity(0.78)

    static let biteRingNutrition = Color(hex: 0xF43F3F)
    static let biteRingRecovery  = Color(hex: 0x2BB36A)
    static let biteRingSleep     = Color(hex: 0x7C6BD9)

    static let biteHydration     = Color(hex: 0x5BA8E5)
    static let biteCarbs         = Color(hex: 0xF4A532)
    static let biteFat           = Color(hex: 0x7C6BD9)
    static let biteFiber         = Color(hex: 0x2BB36A)
    static let biteWarning       = Color(hex: 0xF4A532)
}

enum BiteTheme {
    static let cardCornerRadius: CGFloat = 22
    static let smallCardCornerRadius: CGFloat = 16
    static let pillCornerRadius: CGFloat = 999
    static let drawerCornerRadius: CGFloat = 28
    static let composerHeight: CGFloat = 50
    static let askPillBottomInset: CGFloat = 112
    static let tabPillBottomInset: CGFloat = 36
    static let topPadding: CGFloat = 56
    static let bottomFloatingClearance: CGFloat = 110

    // Top safe-area system. Any page that renders chrome above its content
    // (back button, progress, close action) should use BiteTopBar so these
    // dimensions stay in one place. The "reserved zone" is a hard floor for
    // where page content may begin: nothing decorative or interactive may
    // render above y == reservedTopZone except the top bar itself.
    static let topBarButtonSize: CGFloat = 56
    static let topBarHorizontalPadding: CGFloat = 16
    static let topBarTopOffset: CGFloat = 12
    static let reservedTopZone: CGFloat = 150

    /// Live safe-area-top read from the active UIWindowScene. SwiftUI's
    /// `GeometryReader.safeAreaInsets` and `safeAreaInset(edge:)` modifiers
    /// inconsistently report 0 inside ZStacks where one sibling uses
    /// `.ignoresSafeArea()`; this helper sidesteps the framework quirk.
    /// Falls back to 50pt for previews / non-window contexts.
    @MainActor
    static var deviceSafeAreaTop: CGFloat {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? scenes.compactMap { $0 as? UIWindowScene }.first
        let window = windowScene?.windows.first { $0.isKeyWindow }
            ?? windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 50
        #else
        return 50
        #endif
    }
}
