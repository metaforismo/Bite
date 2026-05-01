import SwiftUI

enum BiomarkerHealth {
    case good, mid, bad
    var color: Color {
        switch self {
        case .good: return Color(hex: 0x2BB36A)
        case .mid:  return Color(hex: 0xF4A532)
        case .bad:  return Color(hex: 0xF43F3F)
        }
    }
}

struct MicroBar: View {
    let value: String
    let unit: String
    let label: String
    let status: BiomarkerHealth
    let fillRatio: Double           // 0...1

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.biteInk)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.biteInkFaint)
                }
            }
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(status.color.opacity(0.13))
                    .frame(width: 18, height: 38)
                RoundedRectangle(cornerRadius: 9)
                    .fill(status.color)
                    .frame(width: 18, height: max(8, 38 * fillRatio))
            }
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(.biteInkMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HealthMonitorCard: View {
    struct Pill: Identifiable {
        let id = UUID()
        let value: String
        let unit: String
        let label: String
        let status: BiomarkerHealth
        let fillRatio: Double
    }

    let pills: [Pill]
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HEALTH MONITOR")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.biteInkMuted)
                    Text("Daily biomarker snapshot")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.biteInkFaint)
                }
                Spacer()
                Text(summary)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.biteRed)
            }
            .padding(.leading, 4)
            HStack {
                ForEach(pills) { pill in
                    MicroBar(value: pill.value, unit: pill.unit, label: pill.label, status: pill.status, fillRatio: pill.fillRatio)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
        }
    }
}
