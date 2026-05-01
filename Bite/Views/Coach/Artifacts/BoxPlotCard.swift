import SwiftUI

struct BoxPlotPayload: Decodable, Sendable {
    let title: String
    let yLabel: String?
    let groups: [Group]
    let highlight: String?

    struct Group: Decodable, Sendable, Identifiable {
        let id: UUID
        let label: String
        let color: String?
        let min: Double
        let q1: Double
        let median: Double
        let q3: Double
        let max: Double
    }
}

struct BoxPlotCard: View {
    let artifact: ArtifactMessage
    @State private var payload: BoxPlotPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let p = payload {
                Text(p.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.biteInk)
                Canvas { context, size in
                    drawBoxPlot(context, size: size, payload: p)
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
    }

    private func drawBoxPlot(_ context: GraphicsContext, size: CGSize, payload p: BoxPlotPayload) {
        let groups = p.groups
        guard !groups.isEmpty else { return }
        let yMax = max(groups.map(\.max).max() ?? 100, 1)
        let yMin = min(groups.map(\.min).min() ?? 0, 0)
        let range = max(yMax - yMin, 1)

        // Y-axis grid
        let gridCount = 5
        for i in 0...gridCount {
            let y = size.height - CGFloat(i) / CGFloat(gridCount) * size.height
            var path = Path()
            path.move(to: CGPoint(x: 30, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(Color(hex: 0xF0EFEE)), lineWidth: 1)
            let label = String(Int(yMin + Double(i) / Double(gridCount) * range))
            context.draw(Text(label).font(.system(size: 9)).foregroundStyle(.biteInkFaint),
                         at: CGPoint(x: 16, y: y), anchor: .center)
        }

        let usableWidth = size.width - 30
        let perGroup = usableWidth / CGFloat(groups.count)
        for (idx, group) in groups.enumerated() {
            let centerX = 30 + perGroup * (CGFloat(idx) + 0.5)
            let boxWidth: CGFloat = min(perGroup * 0.6, 60)

            func y(for value: Double) -> CGFloat {
                size.height - CGFloat((value - yMin) / range) * size.height
            }
            let color: Color = {
                if let raw = group.color, let value = UInt32(raw, radix: 16) {
                    return Color(hex: value)
                }
                return .biteRed
            }()

            // whisker
            var whisker = Path()
            whisker.move(to: CGPoint(x: centerX, y: y(for: group.max)))
            whisker.addLine(to: CGPoint(x: centerX, y: y(for: group.min)))
            context.stroke(whisker, with: .color(color), lineWidth: 1)

            // min / max caps
            for v in [group.min, group.max] {
                var cap = Path()
                cap.move(to: CGPoint(x: centerX - boxWidth / 4, y: y(for: v)))
                cap.addLine(to: CGPoint(x: centerX + boxWidth / 4, y: y(for: v)))
                context.stroke(cap, with: .color(color), lineWidth: 1.5)
            }

            // box
            let top = y(for: group.q3)
            let bottom = y(for: group.q1)
            let rect = CGRect(x: centerX - boxWidth / 2, y: top, width: boxWidth, height: bottom - top)
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color.opacity(0.25)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 2), with: .color(color), lineWidth: 1.5)

            // median
            var median = Path()
            median.move(to: CGPoint(x: centerX - boxWidth / 2, y: y(for: group.median)))
            median.addLine(to: CGPoint(x: centerX + boxWidth / 2, y: y(for: group.median)))
            context.stroke(median, with: .color(color), lineWidth: 2)

            // label
            context.draw(Text(group.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.biteInkMuted),
                         at: CGPoint(x: centerX, y: size.height - 4), anchor: .bottom)
        }
    }

    private func decode() {
        guard let decoded = try? JSONDecoder.bite.decode(BoxPlotPayload.self, from: artifact.payloadJSON) else { return }
        payload = decoded
    }
}
