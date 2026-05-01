import SwiftUI

enum OrbMood: String, CaseIterable, Codable {
    case neutral
    case listen
    case think
    case happy
}

enum OrbState: String, Codable {
    case idle
    case thinking
    case listening
    case speaking
    case error
}

struct OrbPalette {
    let core: Color
    let glow: Color
    let deep: Color

    static func palette(for mood: OrbMood) -> OrbPalette {
        switch mood {
        case .neutral: return OrbPalette(core: Color(hex: 0xFF8B8B), glow: Color(hex: 0xFFD5D5), deep: Color(hex: 0xE03A3A))
        case .listen:  return OrbPalette(core: Color(hex: 0xFF7777), glow: Color(hex: 0xFFC4C4), deep: Color(hex: 0xD02B2B))
        case .think:   return OrbPalette(core: Color(hex: 0xFF9C9C), glow: Color(hex: 0xFFE0E0), deep: Color(hex: 0xC72E2E))
        case .happy:   return OrbPalette(core: Color(hex: 0xFFA4A4), glow: Color(hex: 0xFFE4E4), deep: Color(hex: 0xD63B3B))
        }
    }
}

extension CoachPersonality {
    var defaultMood: OrbMood {
        switch self {
        case .dataNerd: return .neutral
        case .guardian: return .happy
        case .friend: return .happy
        case .commander: return .think
        }
    }

    var greeting: String {
        switch self {
        case .dataNerd: return "What should we look at today?"
        case .guardian: return "How are you feeling?"
        case .friend: return "Hey, how's it going?"
        case .commander: return "What's the move today?"
        }
    }
}
