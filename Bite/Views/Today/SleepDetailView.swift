import SwiftUI
import SwiftData

/// Opened from the Sleep ring on Today. Shows last night's sleep, the
/// configured Smart Alarm (if any), and a CTA to open the Smart Alarm sheet.
struct SleepDetailView: View {
    @Bindable var router: BiteRouter

    @Query(sort: [SortDescriptor(\SDSmartAlarm.createdAt, order: .reverse)])
    private var alarms: [SDSmartAlarm]

    let lastNightSleepHours: Double?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x15172A), Color(hex: 0x252A4A), Color(hex: 0x0E1020)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        sleepHero
                        sleepStats
                        recoveryNote
                        smartAlarmRow
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var sleepHero: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(Date(), format: .dateTime.weekday(.wide).month().day())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())
            }

            SleepScoreHero(score: sleepScore, label: qualityLabel)

            HStack(spacing: 10) {
                SleepHeroChip(title: "Time asleep", value: lastNightSleepHours.map { String(format: "%.1f h", $0) } ?? "No data")
                SleepHeroChip(title: "Sleep debt", value: sleepDebtLabel)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var sleepStats: some View {
        HStack(spacing: 10) {
            SleepMetricTile(title: "Efficiency", value: efficiencyLabel, delta: "+2%", tint: .biteRingSleep)
            SleepMetricTile(title: "Consistency", value: "83%", delta: "Stable", tint: .biteHydration)
            SleepMetricTile(title: "Recovery", value: recoveryImpactLabel, delta: qualityLabel, tint: .biteRingRecovery)
        }
    }

    private var recoveryNote: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECOVERY NOTE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.54))
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(recoveryNoteText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                SleepInsightPill(title: "Bedtime", value: "11:18 PM")
                SleepInsightPill(title: "Wake", value: alarms.first?.formattedWakeTime ?? "7:00 AM")
                SleepInsightPill(title: "Latency", value: "18 min")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var smartAlarmRow: some View {
        Button {
            dismiss()
            router.openModal(.smartAlarm)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Smart alarm")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(smartAlarmSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(14)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var sleepScore: Int {
        guard let h = lastNightSleepHours else { return 0 }
        return Int(min(100, max(35, (h / 8.0) * 100)).rounded())
    }

    private var qualityLabel: String {
        guard let h = lastNightSleepHours else { return "No data" }
        if h >= 7.5 { return "Optimal" }
        if h >= 6.5 { return "Good" }
        return "Catch up"
    }

    private var sleepDebtLabel: String {
        guard let h = lastNightSleepHours else { return "—" }
        let debt = max(0, 8.0 - h)
        return debt == 0 ? "0 min" : "\(Int(debt * 60)) min"
    }

    private var efficiencyLabel: String {
        guard let h = lastNightSleepHours else { return "—" }
        if h >= 7.5 { return "91%" }
        if h >= 6.5 { return "86%" }
        return "78%"
    }

    private var recoveryImpactLabel: String {
        guard let h = lastNightSleepHours else { return "—" }
        if h >= 7.5 { return "High" }
        if h >= 6.5 { return "Med" }
        return "Low"
    }

    private var recoveryNoteText: String {
        guard let h = lastNightSleepHours else {
            return "Connect Apple Health or a wearable so Bite can connect sleep duration, HRV, resting heart rate, and training readiness."
        }
        if h >= 7.5 {
            return "Strong sleep base. Bite can keep normal training pressure today unless HRV or resting heart rate says otherwise."
        }
        if h >= 6.5 {
            return "Reasonable night, but keep high-intensity work honest. A short walk and earlier caffeine cutoff can help tonight."
        }
        return "Recovery is constrained. Bias toward easy movement, hydration, and an earlier wind-down instead of chasing volume."
    }

    private var smartAlarmSubtitle: String {
        if let alarm = alarms.first {
            return "\(alarm.formattedWakeTime) • \(alarm.windowMinutes) min window • \(alarm.hapticIntensity.displayName)"
        }
        return "Wake during light sleep"
    }
}

private struct SleepScoreHero: View {
    let score: Int
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 16)
                .frame(width: 156, height: 156)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    AngularGradient(colors: [.biteRingSleep, .biteHydration, .biteRingSleep], center: .center),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 156, height: 156)
            VStack(spacing: 4) {
                Text("\(score)%")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct SleepHeroChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SleepMetricTile: View {
    let title: String
    let value: String
    let delta: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.16), in: Circle())
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10.5, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                Text(delta)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.44))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct SleepInsightPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
