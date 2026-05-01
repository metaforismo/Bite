import WidgetKit
import SwiftUI

struct MacrosWidget: Widget {
    let kind: String = "MacrosWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BiteSnapshotProvider()) { entry in
            MacrosView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 1.0, green: 0.97, blue: 0.95)
                }
                .widgetURL(URL(string: "bite://journal"))
        }
        .configurationDisplayName("Macros")
        .description("Today's protein, carbs, fat, and fiber.")
        .supportedFamilies([.systemMedium])
    }
}

private struct MacrosView: View {
    let entry: BiteSnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY'S MACROS")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                MacroBar(label: "Protein", value: entry.snapshot.protein, target: 150, color: .blue)
                MacroBar(label: "Carbs",   value: entry.snapshot.carbs,   target: 250, color: .orange)
                MacroBar(label: "Fat",     value: entry.snapshot.fat,     target: 65,  color: .red)
                MacroBar(label: "Fiber",   value: entry.snapshot.fiber,   target: 30,  color: .green)
            }
        }
        .padding(10)
    }
}

private struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color

    private var ratio: Double {
        guard target > 0 else { return 0 }
        return min(1, value / target)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 50, alignment: .leading)
            ProgressView(value: ratio).tint(color)
            Text("\(Int(value))/\(Int(target)) g")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
    }
}
