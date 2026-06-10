import SwiftUI
import Charts

/// Compact line/area sparkline. Used inside cards for trend at-a-glance.
struct BiteSparkline: View {
    let values: [Double]
    var goal: Double? = nil
    var color: Color = .biteRed
    var fillArea: Bool = true
    var height: CGFloat = 32

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                LineMark(
                    x: .value("i", idx),
                    y: .value("v", value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .interpolationMethod(.catmullRom)

                if fillArea {
                    AreaMark(
                        x: .value("i", idx),
                        y: .value("v", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            if let goal {
                RuleMark(y: .value("goal", goal))
                    .foregroundStyle(color.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: height)
    }
}
