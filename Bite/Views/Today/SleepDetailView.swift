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
            ScrollView {
                VStack(spacing: 18) {
                    sleepSummary
                    smartAlarmRow
                    Spacer(minLength: 12)
                }
                .padding(20)
            }
            .background(BiteGradientBackground(style: .today).ignoresSafeArea())
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.biteRed)
                }
            }
        }
    }

    private var sleepSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAST NIGHT")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.biteInkMuted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(lastNightSleepHours.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.biteInk)
                Text("hours")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
            }
            Text(qualityLabel)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.biteRingSleep)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.biteRingSleep.opacity(0.15)))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
    }

    private var smartAlarmRow: some View {
        Button {
            dismiss()
            router.openModal(.smartAlarm)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.biteRingSleep)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.biteRingSleep.opacity(0.15)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Smart alarm")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Text(smartAlarmSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.biteInkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.biteInkFaint)
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var qualityLabel: String {
        guard let h = lastNightSleepHours else { return "No data" }
        if h >= 7.5 { return "Optimal" }
        if h >= 6.5 { return "Good" }
        return "Catch up"
    }

    private var smartAlarmSubtitle: String {
        if let alarm = alarms.first {
            return "\(alarm.formattedWakeTime) • \(alarm.windowMinutes) min window • \(alarm.hapticIntensity.displayName)"
        }
        return "Wake during light sleep"
    }
}
