import SwiftUI

/// Concentric donut showing protein/carbs/fat as 3 nested rings with the
/// total kcal as oversized number at center. Same shape language as
/// `OrbitDial` but specialized for macro split.
struct MacroDonut: View {
    let kcal: Int
    let goalKcal: Int
    let protein: Double  // g
    let carbs: Double
    let fat: Double

    private var proteinKcal: Double { protein * 4 }
    private var carbsKcal: Double { carbs * 4 }
    private var fatKcal: Double { fat * 9 }
    private var totalKcal: Double { max(1, proteinKcal + carbsKcal + fatKcal) }

    private var pPct: Double { proteinKcal / totalKcal }
    private var cPct: Double { carbsKcal / totalKcal }
    private var fPct: Double { fatKcal / totalKcal }

    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let dim = min(geo.size.width, geo.size.height)
            ZStack {
                ringBackground(diameter: dim, inset: 0)
                ringBackground(diameter: dim, inset: 24)
                ringBackground(diameter: dim, inset: 48)

                ringArc(diameter: dim, inset: 0,  fraction: pPct, color: .biteRed)
                ringArc(diameter: dim, inset: 24, fraction: cPct, color: .biteCarbs)
                ringArc(diameter: dim, inset: 48, fraction: fPct, color: .biteFat)

                VStack(spacing: 2) {
                    Text("\(kcal)")
                        .font(.system(size: 38, weight: .heavy))
                        .tracking(-1.2)
                        .foregroundStyle(.biteInk)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("of \(goalKcal) kcal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.biteInkFaint)
                }
            }
            .frame(width: dim, height: dim)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { progress = 1 }
        }
    }

    private func ringBackground(diameter: CGFloat, inset: CGFloat) -> some View {
        Circle()
            .stroke(Color.black.opacity(0.05), lineWidth: 8)
            .frame(width: diameter - inset * 2, height: diameter - inset * 2)
    }

    private func ringArc(diameter: CGFloat, inset: CGFloat, fraction: Double, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: CGFloat(fraction) * progress)
            .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .frame(width: diameter - inset * 2, height: diameter - inset * 2)
            .rotationEffect(.degrees(-90))
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
    }
}
