import SwiftUI

struct ConfidenceDialPayload: Decodable, Sendable {
    let title: String
    let value: Double           // 0...1
    let label: String?          // e.g. "High-quality estimate"
    let drivers: [String]?      // bullet points underneath
}

struct ConfidenceDialCard: View {
    let artifact: ArtifactMessage
    @State private var payload: ConfidenceDialPayload?
    @State private var animatedValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let p = payload {
                Text(p.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.biteInk)
                ZStack {
                    dial(p.value)
                    VStack(spacing: 2) {
                        Text("\(Int(animatedValue * 100))%")
                            .font(.system(size: 28, weight: .heavy))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.biteInk)
                        if let label = p.label {
                            Text(label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.biteInkMuted)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 30)
                }
                .frame(height: 140)

                if let drivers = p.drivers, !drivers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(drivers, id: \.self) { driver in
                            HStack(alignment: .top, spacing: 6) {
                                Circle().fill(.biteRedSoft).frame(width: 4, height: 4).padding(.top, 6)
                                Text(driver)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.biteInkMuted)
                            }
                        }
                    }
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

    private func dial(_ value: Double) -> some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height
            let radius = min(size.width / 2, size.height) - 16

            // Track
            var track = Path()
            track.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(360),
                clockwise: false
            )
            context.stroke(track, with: .color(Color(hex: 0xF2EFEC)), style: StrokeStyle(lineWidth: 14, lineCap: .round))

            // Filled arc
            let endAngle = 180.0 + 180.0 * animatedValue
            var fill = Path()
            fill.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(endAngle),
                clockwise: false
            )
            context.stroke(
                fill,
                with: .linearGradient(
                    Gradient(colors: [.biteRedSoft, .biteRed]),
                    startPoint: CGPoint(x: 0, y: cy),
                    endPoint: CGPoint(x: size.width, y: cy)
                ),
                style: StrokeStyle(lineWidth: 14, lineCap: .round)
            )
        }
        .onAppear {
            withAnimation(BiteMotion.ringDraw) { animatedValue = value }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(BiteMotion.ringDraw) { animatedValue = newValue }
        }
    }

    private func decode() {
        guard let decoded = try? JSONDecoder.bite.decode(ConfidenceDialPayload.self, from: artifact.payloadJSON) else { return }
        payload = decoded
    }
}
