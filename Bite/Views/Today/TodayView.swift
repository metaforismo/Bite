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
    @State private var steps: Int? = nil
    @State private var activeEnergyKcal: Double? = nil
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
    private var consumedProtein: Double { todayEntries.compactMap(\.nutrition?.protein).reduce(0, +) }
    private var consumedCarbs: Double { todayEntries.compactMap(\.nutrition?.carbs).reduce(0, +) }
    private var consumedFat: Double { todayEntries.compactMap(\.nutrition?.fat).reduce(0, +) }

    /// Last 7 days of kcal totals (today is the last element). Used for the
    /// trend sparkline below the rings.
    private var kcalLast7Days: [Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset -> Double in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            let dayStart = cal.startOfDay(for: day)
            let next = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let kcal = allEntries
                .filter { $0.dayStart >= dayStart && $0.dayStart < next }
                .compactMap { $0.toStruct().nutrition?.calories }
                .reduce(0, +)
            return Double(kcal)
        }
    }
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
    private var activityPct: Double {
        min(1, Double(steps ?? 0) / 10_000.0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                date
                statusPills
                dashboardSection
                coachBriefSection
                quickLogSection
                compactTimelineSection
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

            // 7-day kcal sparkline beneath the rings — quick trend at a glance.
            if kcalLast7Days.contains(where: { $0 > 0 }) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("7-DAY KCAL TREND")
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(.biteInkFaint)
                        Text("\(Int(kcalLast7Days.last ?? 0)) today")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.biteInkMuted)
                    }
                    Spacer()
                    BiteSparkline(values: kcalLast7Days, goal: Double(userProfile.calorieGoal), color: .biteRed, fillArea: true, height: 28)
                        .frame(width: 120)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY DASHBOARD")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.biteInkMuted)
                Spacer()
                Text("Apple Health")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.biteInkFaint)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                DashboardMetricCard(
                    title: "Recovery",
                    value: "\(Int(recoveryPct * 100))",
                    unit: "%",
                    subtitle: hrv.map { "HRV \(Int($0)) ms" } ?? "No HRV yet",
                    status: recoveryPct >= 0.75 ? "Ready" : "Recover",
                    color: .biteRingRecovery,
                    progress: recoveryPct,
                    trend: [40, hrv ?? 0, 55, 48, hrv ?? 0]
                ) {
                    router.openChat(prefill: "Explain my recovery today using HRV, resting heart rate, sleep, and activity.")
                }

                DashboardMetricCard(
                    title: "Sleep",
                    value: sleepHours.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "h",
                    subtitle: sleepPct >= 0.85 ? "Goal hit" : "Below target",
                    status: sleepPct >= 0.85 ? "Good" : "Catch up",
                    color: .biteRingSleep,
                    progress: sleepPct,
                    trend: [6.5, 7.2, sleepHours ?? 0]
                ) {
                    showingSleepDetail = true
                }

                DashboardMetricCard(
                    title: "Nutrition",
                    value: "\(consumedKcal)",
                    unit: "kcal",
                    subtitle: "\(Int(consumedProtein))g protein",
                    status: nutritionPct >= 0.95 ? "Done" : "On track",
                    color: .biteRed,
                    progress: nutritionPct,
                    trend: kcalLast7Days
                ) {
                    router.openChat(prefill: "Review my nutrition today against my calories and macros.")
                }

                DashboardMetricCard(
                    title: "Activity",
                    value: "\(steps ?? 0)",
                    unit: "steps",
                    subtitle: activeEnergyKcal.map { "\(Int($0)) active kcal" } ?? "No activity yet",
                    status: activityPct >= 0.8 ? "Moving" : "Build up",
                    color: .biteCarbs,
                    progress: activityPct,
                    trend: [0, Double(steps ?? 0) * 0.35, Double(steps ?? 0) * 0.72, Double(steps ?? 0)]
                ) {
                    router.openChat(prefill: "What activity should I do today based on my recovery and goal?")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var coachBriefSection: some View {
        let copy = StatusInsightCopy.copy(for: currentStatusKind, daysActive: statusDays)
        let message = dailyInsight ?? copy.message
        return Button {
            BiteHaptics.impact(.light)
            router.openChat(prefill: "Give me a concise plan for today using recovery, sleep, nutrition, and activity.")
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Coach brief", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.biteInkMuted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.biteInkFaint)
                }
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.biteInk)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.98))
        .padding(.horizontal, 20)
    }

    private var quickLogSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickLogButton("Food", icon: "fork.knife", color: .biteRed) {
                    router.openChat(prefill: "Log my last meal — what should I tell you?")
                }
                quickLogButton("Water", icon: "drop.fill", color: .biteHydration) {
                    router.openModal(.hydration)
                }
                quickLogButton("Caffeine", icon: "cup.and.saucer.fill", color: .biteCarbs) {
                    router.openModal(.caffeine)
                }
                quickLogButton("Status", icon: currentStatusKind.icon, color: statusIconColor) {
                    router.openModal(.activityStatus)
                }
                quickLogButton("Files", icon: "doc.badge.plus", color: .biteFat) {
                    router.openChat(thenPlus: true)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func quickLogButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            BiteHaptics.selection()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.biteInk)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.96))
    }

    @ViewBuilder
    private var compactTimelineSection: some View {
        if !todayEntries.isEmpty || userProfile.cycleTrackingEnabled {
            VStack(spacing: 10) {
                MealsTimelineCard(entries: todayEntries, consumedKcal: consumedKcal, goalKcal: userProfile.calorieGoal)
                    .askCoachContext("How's my nutrition looking today vs. my goals?")
                if userProfile.cycleTrackingEnabled {
                    CycleCard(
                        onLogTap: { router.openModal(.menstrualLog) },
                        onAskBite: { router.openChat(prefill: "Give me a cycle insight for today.") }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// Macro split donut beneath the meals section — concentric protein/carbs/fat
    /// rings with kcal total at center, in the dial-style visual language.
    @ViewBuilder
    private var macroDonutSection: some View {
        if consumedKcal > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("MACROS TODAY")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.biteInkMuted)
                    .padding(.leading, 4)

                HStack(spacing: 16) {
                    MacroDonut(
                        kcal: consumedKcal,
                        goalKcal: userProfile.calorieGoal,
                        protein: consumedProtein,
                        carbs: consumedCarbs,
                        fat: consumedFat
                    )
                    .frame(width: 160, height: 160)

                    VStack(alignment: .leading, spacing: 10) {
                        macroLegendRow(color: .biteRed, label: "Protein", value: "\(Int(consumedProtein))g", goal: userProfile.proteinGoal)
                        macroLegendRow(color: .biteCarbs, label: "Carbs", value: "\(Int(consumedCarbs))g", goal: userProfile.carbsGoal)
                        macroLegendRow(color: .biteFat, label: "Fat", value: "\(Int(consumedFat))g", goal: userProfile.fatGoal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: BiteTheme.cardCornerRadius, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
                .biteShadow(.raised)
                .askCoachContext("Where am I on macros today vs. my targets?")
            }
            .padding(.horizontal, 20)
        }
    }

    private func macroLegendRow(color: Color, label: String, value: String, goal: Double) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.biteInkMuted)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.biteInk)
                    .monospacedDigit()
                Text("of \(Int(goal))g")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.biteInkFaint)
            }
        }
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

    /// Daily review CTA — opens Coach with a prefilled "How did today go?"
    /// prompt so the user gets a structured walkthrough on demand.
    private var dailyReviewSection: some View {
        Button {
            BiteHaptics.impact(.light)
            router.openChat(prefill: "How did today go? Walk me through my nutrition, recovery, and what to focus on tomorrow.")
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: 0x7C6BD9), Color(hex: 0x5B4DC9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily review with Bite")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text("Get a quick read on today and what to do tomorrow")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.biteInkFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.97))
        .padding(.horizontal, 20)
    }

    /// Document upload entry — drives the "throw any health document at
    /// Bite" loop. Opens Coach with the file picker pre-launched.
    private var documentUploadSection: some View {
        Button {
            BiteHaptics.impact(.light)
            router.openChat(thenPlus: true)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xF4A532).opacity(0.15))
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF4A532))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upload a health document")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text("Lab PDF, prescription, photo — Bite reads it")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.biteInkFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.97))
        .padding(.horizontal, 20)
    }

    // MARK: Data

    private func refresh() async {
        async let hrvTask = healthKit.fetchAverageHRV()
        async let rhrTask = healthKit.fetchRestingHeartRate()
        async let sleepTask = healthKit.fetchLastNightSleepHours()
        async let stepsTask = healthKit.fetchTodaySteps()
        async let activeTask = healthKit.fetchTodayActiveEnergy()
        let (h, r, s, st, active) = await (hrvTask, rhrTask, sleepTask, stepsTask, activeTask)
        await MainActor.run {
            self.hrv = h
            self.rhr = r
            self.sleepHours = s
            self.steps = st
            self.activeEnergyKcal = active
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

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let status: String
    let color: Color
    let progress: Double
    let trend: [Double]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(.biteInkFaint)
                    Spacer()
                    Text(status)
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12), in: Capsule())
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(.biteInk)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.biteInkMuted)
                }

                Text(subtitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    ProgressView(value: min(1, max(0, progress)))
                        .tint(color)
                    if trend.contains(where: { $0 > 0 }) {
                        BiteSparkline(values: trend, goal: nil, color: color, fillArea: false, height: 22)
                            .frame(width: 54, height: 22)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(PressableScaleButtonStyle(pressedScale: 0.98))
    }
}
