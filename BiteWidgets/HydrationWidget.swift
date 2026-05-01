import WidgetKit
import SwiftUI

struct HydrationWidget: Widget {
    let kind: String = "HydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BiteSnapshotProvider()) { entry in
            HydrationView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.18), Color.cyan.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: "bite://hydration"))
        }
        .configurationDisplayName("Hydration")
        .description("Today's hydration vs. your goal.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct HydrationView: View {
    let entry: BiteSnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var ratio: Double {
        guard entry.snapshot.hydrationGoalML > 0 else { return 0 }
        return min(1, entry.snapshot.hydrationML / entry.snapshot.hydrationGoalML)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle().stroke(.tertiary, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "drop.fill")
                    .widgetAccentable()
            }
        case .accessoryRectangular:
            HStack {
                Image(systemName: "drop.fill")
                    .widgetAccentable()
                Text("\(formatLiters(entry.snapshot.hydrationML)) / \(formatLiters(entry.snapshot.hydrationGoalML))")
                    .font(.headline)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.cyan)
                        .widgetAccentable()
                    Text("HYDRATION")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }
                Text("\(formatLiters(entry.snapshot.hydrationML)) / \(formatLiters(entry.snapshot.hydrationGoalML))")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                ProgressView(value: ratio).tint(.cyan)
            }
            .padding(8)
        }
    }

    private func formatLiters(_ ml: Double) -> String {
        if ml >= 1000 { return String(format: "%.1f L", ml / 1000) }
        return "\(Int(ml)) mL"
    }
}
