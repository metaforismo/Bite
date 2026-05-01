import SwiftUI

/// Visual barbell + colored plates. The slider snaps to the symmetric greedy
/// decomposition of the chosen total weight using standard plate denominations
/// (45/35/25/10/5/2.5 lb). Confirm writes the rounded total back to the
/// supplied binding.
struct PlateCalculatorSheet: View {
    @Binding var weightLb: Double
    let onClose: () -> Void

    @State private var draft: Double

    init(weightLb: Binding<Double>, onClose: @escaping () -> Void) {
        self._weightLb = weightLb
        self.onClose = onClose
        self._draft = State(initialValue: max(45, weightLb.wrappedValue))
    }

    private static let plates: [Plate] = [
        Plate(weight: 45, color: .red),
        Plate(weight: 35, color: .blue),
        Plate(weight: 25, color: .yellow),
        Plate(weight: 10, color: .green),
        Plate(weight: 5,  color: .white),
        Plate(weight: 2.5, color: .pink),
    ]

    private let barWeight: Double = 45

    private var perSidePlates: [Plate] {
        var remaining = max(0, (draft - barWeight) / 2)
        var result: [Plate] = []
        for plate in Self.plates {
            while remaining + 0.0001 >= plate.weight {
                result.append(plate)
                remaining -= plate.weight
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            Text("\(Int(draft)) lb")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.biteInk)
                .contentTransition(.numericText())

            barbellGraphic

            Slider(value: $draft, in: 45...500, step: 2.5) {
                Text("Weight")
            }
            .tint(.biteRed)
            .padding(.horizontal, 4)

            HStack(spacing: 10) {
                Button {
                    onClose()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    weightLb = draft.rounded()
                    onClose()
                } label: {
                    Text("Confirm")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.biteRed, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.white)
    }

    private var header: some View {
        HStack {
            Text("Plate calculator")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.biteInk)
            Spacer()
            Text("Each side")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.biteInkMuted)
        }
    }

    private var barbellGraphic: some View {
        HStack(spacing: 4) {
            // Left plates (mirrored — heaviest closest to bar)
            ForEach(Array(perSidePlates.reversed().enumerated()), id: \.offset) { _, plate in
                plateView(plate)
            }
            // Bar
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                .frame(width: 80, height: 12)
            // Right plates
            ForEach(Array(perSidePlates.enumerated()), id: \.offset) { _, plate in
                plateView(plate)
            }
        }
        .frame(height: 130)
    }

    private func plateView(_ plate: Plate) -> some View {
        let height = plateHeight(for: plate.weight)
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(plate.color)
            .frame(width: 12, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 0.8)
            )
    }

    private func plateHeight(for weight: Double) -> CGFloat {
        switch weight {
        case 45: return 124
        case 35: return 108
        case 25: return 90
        case 10: return 70
        case 5: return 54
        case 2.5: return 40
        default: return 60
        }
    }

    private struct Plate {
        let weight: Double
        let color: Color
    }
}
