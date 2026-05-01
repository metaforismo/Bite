import WidgetKit
import SwiftUI

struct HealthMonitorWidget: Widget {
    let kind: String = "HealthMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BiteSnapshotProvider()) { entry in
            HealthMonitorView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.96, green: 0.97, blue: 1.0)
                }
                .widgetURL(URL(string: "bite://biology"))
        }
        .configurationDisplayName("Health Monitor")
        .description("HRV, RHR, temperature, and SpO₂ at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

private struct HealthMonitorView: View {
    let entry: BiteSnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HEALTH MONITOR")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                pill(label: "HRV",  value: entry.snapshot.hrv.map { "\(Int($0))" } ?? "—",  color: .green)
                pill(label: "RHR",  value: entry.snapshot.rhr.map { "\(Int($0))" } ?? "—",  color: .red)
                pill(label: "Temp", value: "98.6°", color: .orange)
                pill(label: "SpO₂", value: "98%",   color: .blue)
            }
        }
        .padding(10)
    }

    private func pill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.10))
        }
    }
}
