import SwiftUI

struct DailySummaryBar: View {
    let profile: UserProfile
    let log: DayLog
    var onLongPress: (() -> Void)? = nil

    @State private var isExpanded = false

    private var remaining: Int {
        max(0, profile.calorieGoal - log.totalCalories)
    }

    private var calorieProgress: Double {
        guard profile.calorieGoal > 0 else { return 0 }
        return min(1.0, Double(log.totalCalories) / Double(profile.calorieGoal))
    }

    private var isOverGoal: Bool {
        log.totalCalories > profile.calorieGoal
    }

    var body: some View {
        VStack(spacing: 12) {
            // Calories row
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(isOverGoal ? "+" : "")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOverGoal ? Color.biteRed : .clear)

                Text("\(remaining)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(isOverGoal ? Color.biteRed : Color.primary)
                    .contentTransition(.numericText(value: Double(remaining)))

                Text("kcal rimanenti")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(log.totalCalories)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)

                Text("/ \(profile.calorieGoal)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Calorie progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.08))

                    Capsule()
                        .fill(isOverGoal ? Color.biteRed : Color.biteRed.opacity(0.7))
                        .frame(width: max(4, geo.size.width * calorieProgress))
                }
            }
            .frame(height: 6)

            // Macro bars
            HStack(spacing: 16) {
                macroIndicator(
                    label: "Proteine",
                    current: log.totalProtein,
                    goal: profile.proteinGoal,
                    color: .biteBlue
                )
                macroIndicator(
                    label: "Carboidrati",
                    current: log.totalCarbs,
                    goal: profile.carbsGoal,
                    color: .biteOrange
                )
                macroIndicator(
                    label: "Grassi",
                    current: log.totalFat,
                    goal: profile.fatGoal,
                    color: .biteRed
                )
            }

            // Expanded extra data
            if isExpanded {
                Divider()
                    .padding(.vertical, 2)

                HStack(spacing: 16) {
                    macroIndicator(
                        label: "Fibre",
                        current: log.totalFiber,
                        goal: 25,
                        color: .bitePurple
                    )
                    macroIndicator(
                        label: "Zuccheri",
                        current: log.totalSugar,
                        goal: 50,
                        color: .teal
                    )
                    macroIndicator(
                        label: "Sodio",
                        current: log.totalSodium,
                        goal: 2300,
                        color: .secondary,
                        unit: "mg"
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.3), value: log.totalCalories)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
        .onLongPressGesture {
            onLongPress?()
        }
    }

    // MARK: - Macro Indicator

    private func macroIndicator(label: String, current: Double, goal: Double, color: Color, unit: String = "g") -> some View {
        let progress = goal > 0 ? min(1.0, current / goal) : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(format: "%.0f", current))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: current))

                Text(String(format: "/%.0f%@", goal, unit))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))

                    Capsule()
                        .fill(color)
                        .frame(width: max(3, geo.size.width * progress))
                }
            }
            .frame(height: 4)
        }
    }

}

#Preview {
    ZStack {
        Color.biteBackground.ignoresSafeArea()

        VStack {
            Spacer()
            DailySummaryBar(
                profile: .default,
                log: DayLog(
                    date: Date(),
                    entries: [
                        FoodEntry(
                            text: "Cappuccino e cornetto",
                            nutrition: NutritionInfo(
                                calories: 320,
                                protein: 8,
                                carbs: 45,
                                fat: 12,
                                fiber: 2,
                                sugar: 18,
                                sodium: 120
                            )
                        ),
                        FoodEntry(
                            text: "Pasta al pesto",
                            nutrition: NutritionInfo(
                                calories: 520,
                                protein: 16,
                                carbs: 72,
                                fat: 18,
                                fiber: 3,
                                sugar: 4,
                                sodium: 480
                            )
                        )
                    ]
                )
            )
            .padding(16)
        }
    }
}
