import SwiftUI

/// Sleep marquee — the dial-driven hero modal. Shows wind-down,
/// optimal bedtime, and wake time on a 24h dial with moon/alarm/sun
/// indicators, oversized white time digits on a deep-navy background.
struct SleepDialSheet: View {
    @Bindable var router: BiteRouter

    @State private var lastNightHours: Double? = nil
    @State private var bedtime: Date = Self.defaultBedtime()
    @State private var wakeTime: Date = Self.defaultWakeTime()

    private let healthKit = HealthKitService.shared

    private static func defaultBedtime() -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 20, second: 0, of: Date()) ?? Date()
    }
    private static func defaultWakeTime() -> Date {
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private var windDown: Date {
        Calendar.current.date(byAdding: .minute, value: -30, to: bedtime) ?? bedtime
    }

    private var sleepNeeded: TimeInterval {
        let raw = wakeTime.timeIntervalSince(bedtime)
        // bedtime crosses midnight: add a day
        let positive = raw < 0 ? raw + 24 * 60 * 60 : raw
        return positive.truncatingRemainder(dividingBy: 24 * 60 * 60)
    }

    private var sleepNeededLabel: String {
        let totalMin = Int(sleepNeeded / 60)
        let h = totalMin / 60
        let m = totalMin % 60
        return "\(h)h \(m)m"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x10172E), Color(hex: 0x070B1A)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                handle
                header
                statBar
                dial
                wakeRow
                sleepNeededRow
                Spacer()
                timeline
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Header chrome

    private var handle: some View {
        Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }

    private var header: some View {
        HStack {
            Button(action: { router.closeModal() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            Text("Sleep")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { /* share */ }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share")

                Button(action: { router.openModal(.smartAlarm) }) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Smart alarm")
            }
        }
        .padding(.horizontal, 18)
    }

    private var statBar: some View {
        HStack(alignment: .top, spacing: 0) {
            statCell(label: "Wind down", value: timeString(windDown))
            Divider()
                .frame(width: 1, height: 36)
                .overlay(Color.white.opacity(0.12))
            statCell(label: "Best bedtime", value: timeString(bedtime))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    // MARK: - Dial

    private var dial: some View {
        let arcs: [DialArc] = [
            DialArc(
                startAngle: DialClock.angle(forHour: hour(of: bedtime)),
                endAngle: DialClock.angle(forHour: hour(of: wakeTime) + (hour(of: wakeTime) < hour(of: bedtime) ? 24 : 0)),
                color: Color(hex: 0x6B8FE5),
                width: 14,
                inset: 14
            )
        ]
        let indicators: [DialIndicator] = [
            DialIndicator(angle: DialClock.angle(forHour: hour(of: bedtime)), color: Color(hex: 0x6B8FE5), size: 28, inset: 14, systemImage: "bed.double.fill", glow: true),
            DialIndicator(angle: DialClock.angle(forHour: hour(of: wakeTime)), color: Color(hex: 0xFFC85A), size: 28, inset: 14, systemImage: "alarm.fill", glow: true),
            DialIndicator(angle: DialClock.angle(forHour: 0), color: Color(hex: 0x9DB1FF).opacity(0.7), size: 16, inset: 14, systemImage: "moon.stars.fill", glow: false),
            DialIndicator(angle: DialClock.angle(forHour: 12), color: Color(hex: 0xFFD66B).opacity(0.7), size: 16, inset: 14, systemImage: "sun.max.fill", glow: false),
        ]
        return OrbitDial(theme: .sleep, arcs: arcs, indicators: indicators) {
            Image(systemName: "moon.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color(hex: 0x9DB1FF))
        }
        .frame(maxWidth: 320, maxHeight: 320)
        .padding(.horizontal, 24)
    }

    // MARK: - Rows

    private var wakeRow: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Text("Wake up at")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                Text(timeString(wakeTime))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 18)
    }

    private var sleepNeededRow: some View {
        HStack {
            Text("Sleep needed tonight")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 4) {
                Text(sleepNeededLabel)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 4) {
                Text("No activity yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text("Once added, an activity will appear here.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
    }

    // MARK: - Helpers

    private func hour(of date: Date) -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func timeString(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}
