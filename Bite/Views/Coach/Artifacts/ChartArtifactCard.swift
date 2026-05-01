import SwiftUI
import Charts

struct ChartArtifactPayload: Decodable, Sendable {
    let kind: String                 // "bar" | "line"
    let title: String
    let series: [Series]
    let yLabel: String?
    let xLabel: String?
    let highlight: String?           // optional caption underneath

    struct Series: Decodable, Sendable, Identifiable {
        let id: UUID
        let name: String
        let color: String?           // hex string like "F43F3F"
        let points: [Point]

        struct Point: Decodable, Sendable, Identifiable {
            let id: UUID
            let x: String            // ISO date string or label
            let y: Double
        }
    }
}

struct ChartArtifactCard: View {
    let artifact: ArtifactMessage
    @State private var payload: ChartArtifactPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let p = payload {
                Text(p.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.biteInk)
                Group {
                    switch p.kind {
                    case "bar":  barChart(p)
                    case "line": lineChart(p)
                    default:     barChart(p)
                    }
                }
                .frame(height: 160)
                if let h = p.highlight {
                    Text(h)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .onAppear { decode() }
        .onChange(of: artifact.version) { _, _ in decode() }
    }

    private func barChart(_ p: ChartArtifactPayload) -> some View {
        Chart {
            ForEach(p.series) { series in
                ForEach(series.points) { point in
                    BarMark(
                        x: .value("x", point.x),
                        y: .value("y", point.y)
                    )
                    .foregroundStyle(color(for: series))
                    .cornerRadius(6)
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .animation(BiteMotion.chartDraw, value: p.series.flatMap(\.points).map(\.y))
    }

    private func lineChart(_ p: ChartArtifactPayload) -> some View {
        Chart {
            ForEach(p.series) { series in
                ForEach(series.points) { point in
                    LineMark(
                        x: .value("x", point.x),
                        y: .value("y", point.y),
                        series: .value("series", series.name)
                    )
                    .foregroundStyle(color(for: series))
                    .interpolationMethod(.catmullRom)
                }
                ForEach(series.points) { point in
                    AreaMark(
                        x: .value("x", point.x),
                        y: .value("y", point.y),
                        series: .value("series", series.name)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color(for: series).opacity(0.30), color(for: series).opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
    }

    private func color(for series: ChartArtifactPayload.Series) -> Color {
        if let hex = series.color, let value = UInt32(hex, radix: 16) {
            return Color(hex: value)
        }
        return .biteRed
    }

    private func decode() {
        guard let decoded = try? JSONDecoder.bite.decode(ChartArtifactPayload.self, from: artifact.payloadJSON) else { return }
        payload = decoded
    }
}
