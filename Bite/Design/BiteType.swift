import SwiftUI

/// Centralized typography scale. Replaces the dozens of inline
/// `.font(.system(size: X, weight: Y))` calls scattered through the app.
///
/// Usage: `Text("…").biteFont(.headline)`.
enum BiteType {
    case display    // 30pt heavy   — page titles ("Today", "Journal")
    case title      // 22pt heavy   — major card headers
    case headline   // 17pt bold    — card section headers
    case body       // 14pt medium  — primary body copy
    case callout    // 13pt semibold — supporting body / metric labels
    case caption    // 12pt medium  — secondary metadata
    case label      // 11pt bold caps-tracked — eyebrow labels

    var size: CGFloat {
        switch self {
        case .display:  return 30
        case .title:    return 22
        case .headline: return 17
        case .body:     return 14
        case .callout:  return 13
        case .caption:  return 12
        case .label:    return 11
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .title:        return .heavy
        case .headline, .label:       return .bold
        case .callout:                return .semibold
        case .body, .caption:         return .medium
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display:  return -1
        case .title:    return -0.4
        case .headline: return -0.2
        case .label:    return 0.6
        default:        return 0
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .display, .title: return 2
        case .headline:        return 1.5
        default:               return 1
        }
    }

    var font: Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    /// Apply a `BiteType` style — sets font, tracking, and line spacing.
    func biteFont(_ style: BiteType) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}
