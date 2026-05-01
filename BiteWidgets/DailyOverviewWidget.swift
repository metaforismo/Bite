import WidgetKit
import SwiftUI

struct DailyOverviewWidget: Widget {
    let kind: String = "DailyOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BiteSnapshotProvider()) { entry in
            DailyOverviewView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.97, blue: 0.95), Color(red: 1.0, green: 0.94, blue: 0.92)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: "bite://today"))
        }
        .configurationDisplayName("Daily Overview")
        .description("Three rings — nutrition, recovery, sleep.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DailyOverviewView: View {
    let entry: BiteSnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DAY AT A GLANCE")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .widgetAccentable()
            HStack(spacing: family == .systemSmall ? 6 : 14) {
                MiniRing(percent: entry.snapshot.nutritionPercent, color: .red, label: "Nutr")
                MiniRing(percent: entry.snapshot.recoveryPercent, color: .green, label: "Rec")
                MiniRing(percent: entry.snapshot.sleepPercent, color: .purple, label: "Sleep")
            }
        }
        .padding(8)
    }
}

private struct MiniRing: View {
    let percent: Double
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0, min(1, percent)))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(round(percent * 100)))")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.primary)
            }
            .frame(width: 36, height: 36)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
