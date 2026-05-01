import SwiftUI

enum BiteGradientStyle {
    case today
    case coach
    case files

    fileprivate var stops: [Gradient.Stop] {
        switch self {
        case .today:
            return [
                .init(color: Color(hex: 0xF43F3F).opacity(0.10), location: 0.00),
                .init(color: Color(hex: 0xFFFBF8),               location: 0.45),
                .init(color: Color(hex: 0xFAF7F2),               location: 1.00),
            ]
        case .coach:
            return [
                .init(color: Color(hex: 0xF43F3F).opacity(0.08), location: 0.00),
                .init(color: .biteBgWarm,                         location: 0.35),
                .init(color: .biteBgCool,                         location: 1.00),
            ]
        case .files:
            return [
                .init(color: Color(hex: 0xF43F3F).opacity(0.07), location: 0.00),
                .init(color: .biteBgWarm,                         location: 0.50),
                .init(color: .biteBgCool,                         location: 1.00),
            ]
        }
    }

    fileprivate var center: UnitPoint {
        switch self {
        case .today: return UnitPoint(x: 0.5, y: -0.20)
        case .coach: return UnitPoint(x: 0.5, y: 0.0)
        case .files: return UnitPoint(x: 0.8, y: 0.0)
        }
    }

    fileprivate var radius: (width: CGFloat, height: CGFloat) {
        switch self {
        case .today: return (1.40, 0.60)
        case .coach: return (1.20, 0.80)
        case .files: return (1.20, 0.90)
        }
    }
}

struct BiteGradientBackground: View {
    let style: BiteGradientStyle

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let r = style.radius
            RadialGradient(
                gradient: Gradient(stops: style.stops),
                center: style.center,
                startRadius: 0,
                endRadius: max(size.width * r.width, size.height * r.height)
            )
            .ignoresSafeArea()
        }
    }
}

#Preview("Today") {
    BiteGradientBackground(style: .today)
}

#Preview("Coach") {
    BiteGradientBackground(style: .coach)
}

#Preview("Files") {
    BiteGradientBackground(style: .files)
}
