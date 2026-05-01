import SwiftUI
import SwiftData
import Charts

/// Re-skinned legacy diary surfaced under the Journal tab.
/// Phase 2 added a top stats strip (streak + 7-day kcal trend) and a
/// calendar heatmap of logged days driven by `JournalAnalyticsService`.
struct JournalView: View {
    @State private var vm: DiaryViewModel = DiaryViewModel()
    @State private var profile = StorageService.shared.loadProfile()
    @State private var tab: Tab = .diary

    @Query(sort: [SortDescriptor(\SDFoodEntry.dayStart, order: .forward)])
    private var allEntries: [SDFoodEntry]

    private let analytics = JournalAnalyticsService()

    enum Tab: Hashable, CaseIterable { case diary, insights }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BiteTopBar(onBack: nil) { EmptyView() }

                header

                statsStrip

                Picker("", selection: $tab) {
                    Text("Diary").tag(Tab.diary)
                    Text("Insights").tag(Tab.insights)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                switch tab {
                case .diary:
                    DiaryView(vm: vm, userProfile: profile)
                case .insights:
                    insightsContent
                }
            }
            .padding(.top, BiteTheme.deviceSafeAreaTop)
            .padding(.bottom, BiteTheme.bottomFloatingClearance + 56)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .task { await vm.loadDay() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Journal")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(.biteInk)
            Spacer()
            streakBadge
        }
        .padding(.horizontal, 20)
    }

    private var streakBadge: some View {
        let streak = analytics.currentStreak(in: allLogs)
        return HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.biteRed)
            Text("\(streak)")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.biteInk)
                .monospacedDigit()
            Text("day\(streak == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.biteInkMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white, in: Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private var statsStrip: some View {
        let avgs = analytics.averages(in: allLogs, weekOffset: 0)
        let trend = analytics.monthlyCalorieTrend(in: allLogs, days: 30)

        return VStack(alignment: .leading, spacing: 10) {
            Text("LAST 30 DAYS")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)

            HStack(spacing: 12) {
                statTile(label: "Avg kcal", value: "\(avgs.calories)", color: .biteRed)
                statTile(label: "Protein", value: "\(Int(avgs.protein))g", color: .biteRed)
                statTile(label: "Carbs", value: "\(Int(avgs.carbs))g", color: .biteCarbs)
                statTile(label: "Fat", value: "\(Int(avgs.fat))g", color: .biteFat)
            }

            if !trend.isEmpty {
                Chart(trend) { sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("Kcal", sample.calories)
                    )
                    .foregroundStyle(.biteRed)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", sample.date),
                        y: .value("Kcal", sample.calories)
                    )
                    .foregroundStyle(LinearGradient(colors: [.biteRed.opacity(0.25), .biteRed.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.biteInkFaint)
                    }
                }
                .frame(height: 120)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
        .biteShadow(.raised)
        .padding(.horizontal, 20)
    }

    private func statTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(.biteInkFaint)
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insights

    private var insightsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            heatmapCard
            JournalInsightsView()
        }
        .padding(.horizontal, 20)
    }

    private var heatmapCard: some View {
        let goal = max(1, profile.calorieGoal)
        let samples: [Date: Double] = Dictionary(uniqueKeysWithValues: allLogs.map { log in
            let cal = Calendar.current
            let day = cal.startOfDay(for: log.date)
            let intensity = min(1.0, Double(log.totalCalories) / Double(goal))
            return (day, intensity)
        })

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LOGGED DAYS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.biteInkMuted)
                Spacer()
                Text("Past 12 weeks")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.biteInkFaint)
            }
            BiteHeatmap(samples: samples, weeks: 12, color: .biteRed)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.smallCardCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BiteTheme.smallCardCornerRadius, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
        .biteShadow(.raised)
    }

    // MARK: - Helpers

    /// Convert flattened SDFoodEntry rows into per-day DayLog structs the
    /// analytics service consumes.
    private var allLogs: [DayLog] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: allEntries, by: \.dayStart)
        return grouped
            .map { (day, rows) in
                DayLog(
                    date: cal.startOfDay(for: day),
                    entries: rows.sorted { $0.createdAt < $1.createdAt }.map { $0.toStruct() }
                )
            }
            .sorted { $0.date < $1.date }
    }
}
