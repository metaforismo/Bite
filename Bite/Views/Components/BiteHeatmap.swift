import SwiftUI

/// 7-row weekly heatmap (Mon..Sun) over an N-week window. Each cell's
/// fill intensity is `value` clamped 0..1; missing cells render dimmed.
/// Used in JournalView's calendar of logged days.
struct BiteHeatmap: View {
    /// `(date, intensity 0..1)`. Days outside the range render empty.
    let samples: [Date: Double]
    /// Number of weeks back from `referenceDate` to render.
    var weeks: Int = 12
    var referenceDate: Date = .now
    var color: Color = .biteRed
    var onTapDay: ((Date) -> Void)? = nil

    private static let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private var startDate: Date {
        let today = calendar.startOfDay(for: referenceDate)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: weekStart) ?? today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    ForEach(Self.dayLabels, id: \.self) { d in
                        Text(d)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.biteInkFaint)
                            .frame(width: 14, height: 14)
                    }
                }

                HStack(spacing: 4) {
                    ForEach(0..<weeks, id: \.self) { week in
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { dayInWeek in
                                cell(for: date(week: week, dayInWeek: dayInWeek))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let intensity = samples[day] ?? 0
        let isFuture = day > calendar.startOfDay(for: referenceDate)

        Button {
            onTapDay?(day)
        } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(cellFill(intensity: intensity, isFuture: isFuture))
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .disabled(isFuture || onTapDay == nil)
    }

    private func cellFill(intensity: Double, isFuture: Bool) -> Color {
        if isFuture { return Color.black.opacity(0.03) }
        if intensity <= 0 { return Color.black.opacity(0.06) }
        return color.opacity(0.20 + min(1, intensity) * 0.65)
    }

    private func date(week: Int, dayInWeek: Int) -> Date {
        let start = startDate
        return calendar.date(byAdding: .day, value: week * 7 + dayInWeek, to: start) ?? start
    }
}
