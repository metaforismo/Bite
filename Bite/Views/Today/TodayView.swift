import SwiftUI
import SwiftData

struct TodayView: View {
    @Binding var userProfile: UserProfile
    @Environment(BiteRouter.self) private var router

    @Query(sort: [SortDescriptor(\SDFoodEntry.createdAt, order: .forward)])
    private var allEntries: [SDFoodEntry]

    @Query(sort: [SortDescriptor(\SDActivityStatus.startedAt, order: .reverse)])
    private var activityStatuses: [SDActivityStatus]

    @State private var hrv: Double? = nil
    @State private var rhr: Double? = nil
    @State private var sleepHours: Double? = nil
    @State private var dailyInsight: String? = nil
    @State private var showingSleepDetail = false
    @State private var showingSettings = false

    private var currentStatus: SDActivityStatus? { activityStatuses.first }
    private var currentStatusKind: ActivityStatusKind { currentStatus?.kind ?? .active }
    private var statusDays: Int { currentStatus?.daysActive ?? 0 }

    private let healthKit = HealthKitService.shared

    private var todayEntries: [FoodEntry] {
        let day = Calendar.current.startOfDay(for: Date())
        let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        return allEntries
            .filter { $0.dayStart >= day && $0.dayStart < next }
            .map { $0.toStruct() }
    }

    private var consumedKcal: Int { todayEntries.compactMap(\.nutrition?.calories).reduce(0, +) }
    private var nutritionPct: Double {
        guard userProfile.calorieGoal > 0 else { return 0 }
        return min(1, Double(consumedKcal) / Double(userProfile.calorieGoal))
    }
    private var recoveryPct: Double {
        guard let hrv else { return 0 }
        // Rough mapping: HRV 30 → 60%, 70 → 95%. Real product replaces this with a worker-baked score.
        return min(1, max(0.4, (hrv - 20) / 80))
    }
    private var sleepPct: Double {
        guard let sleepHours else { return 0 }
        return min(1, sleepHours / 8.0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                date
                statusPills
                ringsSection
                insightSection
                cycleSection
                healthMonitorSection
                mealsSection
                hydrationStreakSection
                upNextSection
            }
            .padding(.top, BiteTheme.deviceSafeAreaTop)
            .padding(.bottom, BiteTheme.bottomFloatingClearance + 56)
            .padding(.horizontal, 0)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .task { await refresh() }
        .sheet(isPresented: $showingSleepDetail) {
            SleepDetailView(router: router, lastNightSleepHours: sleepHours)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(userProfile: $userProfile)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Sections

    private var header: some View {
        BiteTopBar(onBack: nil) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image("BiteLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(.rect(cornerRadius: 7, style: .continuous))
                    Text("Bite")
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(-0.4)
                        .foregroundStyle(.biteInk)
                }
                Spacer()
                Button {} label: {
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.biteInk)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.85), in: Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notifications")

                Button {
                    BiteHaptics.impact(.light)
                    showingSettings = true
                } label: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xFFD5D5), Color(hex: 0xC72E2E)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(userProfile.name.first.map { String($0).uppercased() } ?? "B")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Account")
            }
        }
    }

    private var date: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(.biteInk)
            HStack(spacing: 4) {
                Text(Date(), format: .dateTime.weekday(.wide).month().day())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var statusPills: some View {
        HStack(spacing: 10) {
            Button {
                router.openModal(.activityStatus)
            } label: {
                StatusPill(
                    systemImage: currentStatusKind.icon,
                    iconColor: statusIconColor,
                    title: statusTitle,
                    sub: statusSub,
                    tint: statusTint
                )
            }
            .buttonStyle(.plain)
            StatusPill(
                systemImage: "sun.max.fill",
                iconColor: Color(hex: 0xF4A532),
                title: "72°F",
                sub: "New York, NY",
                tint: Color(hex: 0xF4A532).opacity(0.12)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var statusIconColor: Color {
        switch currentStatusKind {
        case .active: return Color(hex: 0x2BB36A)
        case .sick: return .biteWarning
        case .injured where statusDays >= 7: return .biteRed
        case .injured: return .biteOrange
        case .onBreak: return .biteInkMuted
        }
    }

    private var statusTint: Color {
        switch currentStatusKind {
        case .active: return Color(hex: 0x2BB36A).opacity(0.12)
        case .sick: return Color.biteWarning.opacity(0.14)
        case .injured where statusDays >= 7: return Color.biteRed.opacity(0.14)
        case .injured: return Color.biteOrange.opacity(0.14)
        case .onBreak: return Color.black.opacity(0.06)
        }
    }

    private var statusTitle: String {
        switch currentStatusKind {
        case .injured where statusDays >= 7: return "\(currentStatusKind.displayName) · 7d+"
        default: return currentStatusKind.displayName
        }
    }

    private var statusSub: String {
        if currentStatusKind == .active {
            return "Until changed"
        }
        return statusDays == 0 ? "Today" : "Day \(statusDays + 1)"
    }

    private var ringsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR DAY AT A GLANCE")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
                .padding(.leading, 4)
            RingsCard(
                nutrition: nutritionPct,
                recovery: recoveryPct,
                sleep: sleepPct,
                nutritionSub: nutritionPct >= 0.95 ? "Goal hit" : "On track",
                recoverySub: recoveryPct >= 0.85 ? "Optimal" : (recoveryPct >= 0.65 ? "Good" : "Recover"),
                sleepSub: sleepPct >= 0.85 ? "Good" : "Catch up",
                onSleepTap: { showingSleepDetail = true }
            )
            .askCoachContext("Walk me through my rings — what should I focus on today?")
        }
        .padding(.horizontal, 20)
    }

    private var insightSection: some View {
        let copy = StatusInsightCopy.copy(for: currentStatusKind, daysActive: statusDays)
        let title = dailyInsight == nil ? copy.title : "Morning signal"
        let message = dailyInsight ?? copy.message
        return InsightCard(
            title: title,
            message: message,
            onTapViewMore: { router.openChat(prefill: copy.ctaPrefill) },
            heroImageName: "TakeItEasy"
        )
        .padding(.horizontal, 20)
    }

    private var healthMonitorSection: some View {
        HealthMonitorCard(
            pills: [
                .init(value: hrv.map { String(Int($0)) } ?? "—", unit: "", label: "HRV", status: .good, fillRatio: hrv.map { min(1, $0 / 80) } ?? 0),
                .init(value: rhr.map { String(Int($0)) } ?? "—", unit: "", label: "RHR", status: .good, fillRatio: rhr.map { 1 - min(1, $0 / 100) } ?? 0),
                .init(value: "98.6", unit: "°F", label: "Temp", status: .good, fillRatio: 0.5),
                .init(value: "98", unit: "%", label: "SpO₂", status: .good, fillRatio: 0.78),
            ],
            summary: hrv == nil ? "Connect Apple Health" : "All in range"
        )
        .padding(.horizontal, 20)
        .askCoachContext("What do my biomarkers tell you about today?")
    }

    private var mealsSection: some View {
        MealsTimelineCard(entries: todayEntries, consumedKcal: consumedKcal, goalKcal: userProfile.calorieGoal)
            .padding(.horizontal, 20)
            .askCoachContext("How's my nutrition looking today vs. my goals?")
    }

    @ViewBuilder
    private var cycleSection: some View {
        if userProfile.cycleTrackingEnabled {
            CycleCard(
                onLogTap: { router.openModal(.menstrualLog) },
                onAskBite: { router.openChat(prefill: "Give me a cycle insight for today.") }
            )
            .padding(.horizontal, 20)
        }
    }

    private var hydrationStreakSection: some View {
        VStack(spacing: 10) {
            HydrationStreakRow(
                onHydrationTap: { router.openModal(.hydration) },
                streakDays: streakDays(),
                last7Active: last7Active()
            )
            .askCoachContext("Am I hitting my hydration goals this week?")
            CaffeineCard(onTap: { router.openModal(.caffeine) })
                .askCoachContext("Is my caffeine intake affecting my sleep?")
        }
        .padding(.horizontal, 20)
    }

    private var upNextSection: some View {
        UpNextCard(items: [])
            .padding(.horizontal, 20)
    }

    // MARK: Data

    private func refresh() async {
        async let hrvTask = healthKit.fetchAverageHRV()
        async let rhrTask = healthKit.fetchRestingHeartRate()
        async let sleepTask = healthKit.fetchLastNightSleepHours()
        let (h, r, s) = await (hrvTask, rhrTask, sleepTask)
        await MainActor.run {
            self.hrv = h
            self.rhr = r
            self.sleepHours = s
        }
    }

    private func streakDays() -> Int {
        // Count consecutive trailing days that have at least one entry.
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var count = 0
        let dayBuckets = Set(allEntries.map { cal.startOfDay(for: $0.createdAt) })
        while dayBuckets.contains(day) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    private func last7Active() -> [Bool] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayBuckets = Set(allEntries.map { cal.startOfDay(for: $0.createdAt) })
        // Return Mon..Sun for the current ISO week.
        let weekday = cal.component(.weekday, from: today)
        // weekday: 1 = Sun, 2 = Mon, ... 7 = Sat. We want Monday-first.
        let mondayOffset = ((weekday + 5) % 7)
        guard let monday = cal.date(byAdding: .day, value: -mondayOffset, to: today) else {
            return Array(repeating: false, count: 7)
        }
        return (0..<7).map { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: monday) else { return false }
            return dayBuckets.contains(d)
        }
    }
}
