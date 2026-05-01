import SwiftUI
import SwiftData

struct JournalInsightsView: View {
    @Query(sort: [SortDescriptor(\SDJournalTag.createdAt, order: .reverse)])
    private var tags: [SDJournalTag]

    private var disabledTags: Set<String> { JournalTagCatalog.disabledSet() }

    /// Demo bars when the user hasn't accumulated enough tagged data yet —
    /// shows the same shape as the eventual worker-backed insights so the UX
    /// has something to render. Replaced by /v1/journal/insights wiring later.
    private var demoBars: [InsightBar] {
        [
            InsightBar(tag: "67+ nutrition score", deltaPercent:  8, metric: .recovery, isPositive: true),
            InsightBar(tag: "10k+ steps",          deltaPercent: 12, metric: .recovery, isPositive: true),
            InsightBar(tag: "Good sleep",          deltaPercent:  6, metric: .recovery, isPositive: true),
            InsightBar(tag: "Late meal",           deltaPercent: 11, metric: .recovery, isPositive: false),
            InsightBar(tag: "Alcohol",             deltaPercent: 14, metric: .recovery, isPositive: false),
            InsightBar(tag: "Caffeine after 4pm",  deltaPercent:  7, metric: .sleep,    isPositive: false),
        ]
    }

    private var bars: [InsightBar] {
        demoBars.filter { !disabledTags.contains($0.tag) }
    }

    private var positiveBars: [InsightBar] { bars.filter(\.isPositive) }
    private var negativeBars: [InsightBar] { bars.filter { !$0.isPositive } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section(title: "HABITS THAT HELPED", icon: "arrow.up.right.circle.fill", tint: .biteRingRecovery, bars: positiveBars)
            section(title: "HABITS THAT HURT", icon: "arrow.down.right.circle.fill", tint: .biteRed, bars: negativeBars)
            disclaimer
        }
    }

    @ViewBuilder
    private func section(title: String, icon: String, tint: Color, bars: [InsightBar]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.biteInkMuted)
            }
            VStack(spacing: 6) {
                ForEach(bars) { bar in
                    InsightBarRow(bar: bar)
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("Insights are based on patterns in your last 30 days. Real-time data improves accuracy as you log more.")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.biteInkFaint)
            .multilineTextAlignment(.leading)
            .padding(.top, 4)
    }
}

struct InsightBar: Identifiable, Hashable {
    let id = UUID()
    let tag: String
    let deltaPercent: Int   // absolute value
    let metric: Metric
    let isPositive: Bool

    enum Metric: String { case recovery, sleep, nutrition }
}

private struct InsightBarRow: View {
    let bar: InsightBar

    private var color: Color { bar.isPositive ? .biteRingRecovery : .biteRed }
    private var sign: String { bar.isPositive ? "+" : "−" }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bar.tag)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.biteInk)
                Text(bar.metric.rawValue.capitalized)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.biteInkFaint)
            }
            Spacer()
            HStack(spacing: 6) {
                GeometryReader { geo in
                    let width = max(20, geo.size.width * CGFloat(min(20, bar.deltaPercent)) / 20)
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.12)).frame(height: 8)
                        Capsule().fill(color).frame(width: width, height: 8)
                    }
                }
                .frame(width: 90, height: 8)

                Text("\(sign)\(bar.deltaPercent)%")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}
