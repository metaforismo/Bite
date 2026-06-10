import SwiftUI

/// 3-step shadow elevation ladder. Replaces ad-hoc `shadow(opacity: 0.04…0.16)`
/// usage so depth hierarchy is consistent and tweakable in one place.
enum BiteElevation {
    case raised   // small cards, default UI surfaces
    case floating // pills, FABs, sticky elements
    case modal    // sheets, full-screen overlays

    var radius: CGFloat {
        switch self {
        case .raised:   return 8
        case .floating: return 18
        case .modal:    return 32
        }
    }

    var opacity: Double {
        switch self {
        case .raised:   return 0.06
        case .floating: return 0.10
        case .modal:    return 0.18
        }
    }

    var y: CGFloat {
        switch self {
        case .raised:   return 2
        case .floating: return 6
        case .modal:    return 16
        }
    }
}

extension View {
    func biteShadow(_ elevation: BiteElevation) -> some View {
        shadow(
            color: .black.opacity(elevation.opacity),
            radius: elevation.radius,
            x: 0,
            y: elevation.y
        )
    }
}
