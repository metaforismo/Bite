import SwiftUI
import Charts

struct AnalyticsView: View {
    @State var vm = AnalyticsViewModel()
    var userProfile: UserProfile

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $vm.selectedTab) {
                    Text("Statistiche").tag(AnalyticsViewModel.AnalyticsTab.stats)
                    Text("Streaks \u{1F525} \(vm.currentStreak)").tag(AnalyticsViewModel.AnalyticsTab.streaks)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch vm.selectedTab {
                case .stats:
                    statsContent
                case .streaks:
                    streaksContent
                }
            }
            .background(Color.biteBackground)
            .navigationTitle("Analisi")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { vm.loadData() }
    }

    // MARK: - Stats Tab

    private var statsContent: some View {
        VStack(spacing: 0) {
            weekNavigator
            ScrollView {
                VStack(spacing: 16) {
                    // Monthly trend chart
                    monthlyTrendChart
                    statCard(
                        icon: "\u{1F37D}",
                        title: "Calorie",
                        avg: "\(vm.avgCalories) kcal/giorno",
                        values: vm.weekDayLogs.map { Double($0?.totalCalories ?? 0) },
                        goal: Double(userProfile.calorieGoal),
                        barColor: .biteRed
                    )
                    statCard(
                        icon: "\u{1F95A}",
                        title: "Proteine",
                        avg: String(format: "%.0fg/giorno", vm.avgProtein),
                        values: vm.weekDayLogs.map { $0?.totalProtein ?? 0 },
                        goal: userProfile.proteinGoal,
                        barColor: .biteBlue
                    )
                    statCard(
                        icon: "\u{1F34E}",
                        title: "Carboidrati",
                        avg: String(format: "%.0fg/giorno", vm.avgCarbs),
                        values: vm.weekDayLogs.map { $0?.totalCarbs ?? 0 },
                        goal: userProfile.carbsGoal,
                        barColor: .biteOrange
                    )
                    statCard(
                        icon: "\u{1FAE7}",
                        title: "Grassi",
                        avg: String(format: "%.0fg/giorno", vm.avgFat),
                        values: vm.weekDayLogs.map { $0?.totalFat ?? 0 },
                        goal: userProfile.fatGoal,
                        barColor: .biteRed
                    )
                }
                .padding()
            }
        }
    }

    private var weekNavigator: some View {
        HStack {
            Button { vm.changeWeek(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(vm.weekLabel)
                    .font(.headline)
                if vm.isCurrentWeek {
                    Text("Questa settimana")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button { vm.changeWeek(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
            }
            .disabled(vm.isCurrentWeek)
            .opacity(vm.isCurrentWeek ? 0.3 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Stat Card

    private func statCard(
        icon: String,
        title: String,
        avg: String,
        values: [Double],
        goal: Double,
        barColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\(icon) \(title)")
                    .font(.headline)
                Spacer()
                Text("Media \(avg)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Bar chart
            barChart(values: values, goal: goal, barColor: barColor)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func barChart(values: [Double], goal: Double, barColor: Color) -> some View {
        let maxValue = max(values.max() ?? 0, goal) * 1.15

        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                // Goal line
                if goal > 0 && maxValue > 0 {
                    GeometryReader { geo in
                        let y = geo.size.height * (1 - goal / maxValue)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(.secondary.opacity(0.5))

                        Text(goal < 10 ? String(format: "%.0f", goal) : "\(Int(goal))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .position(x: geo.size.width - 16, y: y - 8)
                    }
                }

                // Bars
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        let value = values[index]
                        let hasData = value > 0

                        VStack(spacing: 0) {
                            if hasData && maxValue > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor)
                                    .frame(width: 24, height: max(4, CGFloat(value / maxValue) * 100))
                            } else {
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 120)

            // Day labels
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Text(vm.dayLabels[index])
                        .font(.caption2)
                        .fontWeight(vm.isDayToday(index) ? .bold : .regular)
                        .foregroundStyle(vm.isDayToday(index) ? Color.biteRed : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Monthly Trend Chart

    private var monthlyTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trend calorie (30 giorni)")
                    .font(.headline)
                Spacer()
            }

            Chart {
                ForEach(vm.monthlyCalorieData, id: \.date) { item in
                    LineMark(
                        x: .value("Data", item.date),
                        y: .value("Calorie", item.calories)
                    )
                    .foregroundStyle(Color.biteRed)
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("Goal", userProfile.calorieGoal))
                    .foregroundStyle(Color.biteRed.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .annotation(position: .trailing, alignment: .trailing) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Streaks Tab

    private var streaksContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Big streak display
                VStack(spacing: 8) {
                    ZStack {
                        Text("\u{1F525}")
                            .font(.system(size: 100))
                            .opacity(0.2)

                        Text("\(vm.currentStreak)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                    }
                    .padding(.top, 20)

                    Text("giorni di fila")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("Record: \(vm.longestStreak)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Calendar
                calendarView
                    .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }

    private var calendarView: some View {
        VStack(spacing: 12) {
            Text(vm.currentMonthName)
                .font(.headline)

            // Weekday headers
            let weekdays = ["L", "M", "M", "G", "V", "S", "D"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                // Empty cells before first day
                ForEach(0..<vm.firstWeekdayOfMonth, id: \.self) { _ in
                    Text("")
                }

                // Day cells
                ForEach(1...vm.daysInCurrentMonth, id: \.self) { day in
                    let hasLog = vm.monthDaysWithLogs.contains(day)
                    let isToday = day == vm.todayDay

                    Text("\(day)")
                        .font(.subheadline)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(hasLog ? .white : (isToday ? .primary : .secondary))
                        .frame(width: 32, height: 32)
                        .background {
                            if hasLog {
                                Circle().fill(Color.biteRed)
                            } else if isToday {
                                Circle().strokeBorder(Color.biteRed, lineWidth: 1.5)
                            }
                        }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    AnalyticsView(userProfile: UserProfile.default)
}
