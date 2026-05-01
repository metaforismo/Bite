import SwiftUI

/// 24h-clock-face primitive used as the visual hero on data surfaces.
/// One shape language, palette swaps via `DialTheme`. Inspired by the
/// iOS Sleep dial — concentric arcs, glow indicators, oversized
/// numeric center.
///
/// Use the static helpers to convert clock times to angles:
/// `OrbitDial.angle(forHour: 22.5)` → degrees from top (12 o'clock).
struct OrbitDial<Center: View>: View {
    let theme: DialTheme
    let arcs: [DialArc]
    let indicators: [DialIndicator]
    let center: () -> Center

    @State private var arcProgress: CGFloat = 0

    init(
        theme: DialTheme,
        arcs: [DialArc] = [],
        indicators: [DialIndicator] = [],
        @ViewBuilder center: @escaping () -> Center = { EmptyView() }
    ) {
        self.theme = theme
        self.arcs = arcs
        self.indicators = indicators
        self.center = center
    }

    var body: some View {
        GeometryReader { geo in
            let dim = min(geo.size.width, geo.size.height)
            let radius = dim / 2

            ZStack {
                // Background ring + gradient halo
                Circle()
                    .fill(theme.surface)
                    .overlay(
                        Circle()
                            .stroke(theme.gridStroke, lineWidth: 1.5)
                    )
                    .shadow(color: theme.glow.opacity(0.35), radius: 18, x: 0, y: 0)

                // Tick marks (every hour, larger every 6h)
                ForEach(0..<48, id: \.self) { i in
                    let isMajor = i % 12 == 0
                    let isHour = i % 2 == 0
                    let length: CGFloat = isMajor ? 10 : (isHour ? 6 : 3)
                    Rectangle()
                        .fill(theme.tickColor.opacity(isMajor ? 0.7 : 0.35))
                        .frame(width: 1, height: length)
                        .offset(y: -(radius - length / 2 - 8))
                        .rotationEffect(.degrees(Double(i) * 7.5))
                }

                // Hour labels at 0/6/12/18 (12AM/6AM/12PM/6PM)
                ForEach(hourLabels, id: \.0) { hour, label in
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.ink.opacity(0.7))
                        .offset(y: -(radius - 28))
                        .rotationEffect(.degrees(Self.angle(forHour: Double(hour))))
                        .rotationEffect(.degrees(-Self.angle(forHour: Double(hour))))
                        .position(
                            x: geo.size.width / 2 + sin(Self.radians(forHour: Double(hour))) * (radius - 28),
                            y: geo.size.height / 2 - cos(Self.radians(forHour: Double(hour))) * (radius - 28)
                        )
                }

                // Arcs
                ForEach(Array(arcs.enumerated()), id: \.offset) { idx, arc in
                    DialArcShape(startAngle: arc.startAngle, endAngle: arc.endAngle, progress: arcProgress)
                        .stroke(arc.color, style: StrokeStyle(lineWidth: arc.width, lineCap: .round))
                        .frame(width: dim - arc.inset * 2, height: dim - arc.inset * 2)
                        .shadow(color: arc.color.opacity(0.4), radius: 8, x: 0, y: 0)
                }

                // Indicators
                ForEach(indicators) { ind in
                    indicatorView(ind, radius: radius)
                }

                // Center content
                center()
            }
            .frame(width: dim, height: dim)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { arcProgress = 1 }
        }
    }

    @ViewBuilder
    private func indicatorView(_ ind: DialIndicator, radius: CGFloat) -> some View {
        let r = radius - ind.inset
        ZStack {
            if ind.glow {
                Circle()
                    .fill(ind.color.opacity(0.35))
                    .frame(width: ind.size + 8, height: ind.size + 8)
                    .blur(radius: 6)
            }
            Circle()
                .fill(ind.color)
                .frame(width: ind.size, height: ind.size)
            if let icon = ind.systemImage {
                Image(systemName: icon)
                    .font(.system(size: ind.size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .offset(x: sin(.pi * ind.angle / 180) * r, y: -cos(.pi * ind.angle / 180) * r)
    }

    private var hourLabels: [(Int, String)] {
        [(0, "12AM"), (6, "6AM"), (12, "12PM"), (18, "6PM")]
    }

    // MARK: - Angle helpers

    /// 0 hour → 0°, 6 hour → 90°, etc. Hour value can be fractional
    /// (e.g. 22.5 = 22:30).
    static func angle(forHour hour: Double) -> Double {
        (hour.truncatingRemainder(dividingBy: 24) / 24.0) * 360.0
    }

    static func radians(forHour hour: Double) -> Double {
        angle(forHour: hour) * .pi / 180
    }
}

// MARK: - Models

struct DialArc {
    var startAngle: Double  // 0° = 12AM (top), CW
    var endAngle: Double
    var color: Color
    var width: CGFloat = 12
    var inset: CGFloat = 18
}

struct DialIndicator: Identifiable {
    let id = UUID()
    var angle: Double          // 0° = 12AM (top), CW
    var color: Color
    var size: CGFloat = 22
    var inset: CGFloat = 26
    var systemImage: String? = nil
    var glow: Bool = false
}

private struct DialArcShape: Shape {
    var startAngle: Double
    var endAngle: Double
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // SwiftUI's .topTrailing-style arc starts at 3 o'clock (0°). We want
        // 12 o'clock (-90°) so subtract 90 from the inputs.
        let s = Angle.degrees(startAngle - 90)
        let span = (endAngle - startAngle).truncatingRemainder(dividingBy: 360)
        let normalisedSpan = span < 0 ? span + 360 : span
        let e = Angle.degrees(startAngle - 90 + Double(progress) * normalisedSpan)

        path.addArc(center: center, radius: radius, startAngle: s, endAngle: e, clockwise: false)
        return path
    }
}

// MARK: - Themes

enum DialTheme {
    case sleep
    case hydration
    case cycle
    case activity
    case biology
    case nutrition
    case fitness

    var surface: AnyShapeStyle {
        switch self {
        case .sleep:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x1A2342), Color(hex: 0x0F162B)], startPoint: .top, endPoint: .bottom))
        case .hydration:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xE6F4FA), Color(hex: 0xBADCEF)], startPoint: .top, endPoint: .bottom))
        case .cycle:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE5EC), Color(hex: 0xFFC2CE)], startPoint: .top, endPoint: .bottom))
        case .activity:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFF1E0), Color(hex: 0xFFD2B0)], startPoint: .top, endPoint: .bottom))
        case .biology:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x2A1B4A), Color(hex: 0x130820)], startPoint: .top, endPoint: .bottom))
        case .nutrition:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFF6F2), Color(hex: 0xFFE2C9)], startPoint: .top, endPoint: .bottom))
        case .fitness:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x222222), Color(hex: 0x111111)], startPoint: .top, endPoint: .bottom))
        }
    }

    var ink: Color {
        switch self {
        case .sleep, .biology, .fitness: return .white
        default: return .biteInk
        }
    }

    var glow: Color {
        switch self {
        case .sleep:     return Color(hex: 0x6B8FE5)
        case .hydration: return Color(hex: 0x5BA8E5)
        case .cycle:     return Color(hex: 0xFF7A99)
        case .activity:  return Color(hex: 0xF4A532)
        case .biology:   return Color(hex: 0x9C7BFF)
        case .nutrition: return Color(hex: 0xF4A532)
        case .fitness:   return Color(hex: 0xFF4D4D)
        }
    }

    var tickColor: Color { ink }

    var gridStroke: Color { ink.opacity(0.08) }

    var primaryArc: Color { glow }

    var secondaryArc: Color { glow.opacity(0.6) }
}
