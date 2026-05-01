import WidgetKit
import SwiftUI

struct EnergyBankWidget: Widget {
    let kind: String = "EnergyBankWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BiteSnapshotProvider()) { entry in
            EnergyBankView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.orange.opacity(0.16), Color.orange.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: "bite://journal"))
        }
        .configurationDisplayName("Energy Bank")
        .description("Calories remaining vs. your daily goal.")
        .supportedFamilies([.systemSmall, .accessoryInline])
    }
}

private struct EnergyBankView: View {
    let entry: BiteSnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var remaining: Int {
        max(0, entry.snapshot.calorieGoal - entry.snapshot.consumedCalories)
    }

    private var ratio: Double {
        guard entry.snapshot.calorieGoal > 0 else { return 0 }
        return min(1, Double(remaining) / Double(entry.snapshot.calorieGoal))
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(remaining) kcal left")
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "battery.75percent")
                        .foregroundStyle(.green)
                        .widgetAccentable()
                    Text("ENERGY BANK")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Text("\(remaining)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text("kcal left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                ProgressView(value: ratio).tint(.green)
            }
            .padding(10)
        }
    }
}
