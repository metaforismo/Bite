import SwiftUI

struct DayDetailSheet: View {
    let profile: UserProfile
    let log: DayLog

    @Environment(\.dismiss) private var dismiss

    private var calorieProgress: Double {
        guard profile.calorieGoal > 0 else { return 0 }
        return Double(log.totalCalories) / Double(profile.calorieGoal)
    }

    private var isOverGoal: Bool {
        log.totalCalories > profile.calorieGoal
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    calorieRing
                    macrosSection
                    deficitMessages
                    foodListSection
                    microSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.biteBackground)
            .navigationTitle("Riepilogo giornata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Calorie Ring

    private var calorieRing: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.08), lineWidth: 16)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: min(calorieProgress, 1.0))
                    .stroke(
                        isOverGoal ? Color.biteRed : Color.biteRed.opacity(0.7),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(log.totalCalories)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("/ \(profile.calorieGoal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(isOverGoal ? "Sopra l'obiettivo" : "\(profile.calorieGoal - log.totalCalories) kcal rimanenti")
                .font(.subheadline)
                .foregroundStyle(isOverGoal ? Color.biteRed : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Macros

    private var macrosSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Macronutrienti")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }

            macroDetailRow(
                icon: "p.circle.fill",
                label: "Protein",
                current: log.totalProtein,
                goal: profile.proteinGoal,
                unit: "g",
                color: .biteBlue
            )
            macroDetailRow(
                icon: "c.circle.fill",
                label: "Carbs",
                current: log.totalCarbs,
                goal: profile.carbsGoal,
                unit: "g",
                color: .biteOrange
            )
            macroDetailRow(
                icon: "f.circle.fill",
                label: "Fat",
                current: log.totalFat,
                goal: profile.fatGoal,
                unit: "g",
                color: .biteRed
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    }

    private func macroDetailRow(icon: String, label: String, current: Double, goal: Double, unit: String, color: Color) -> some View {
        let progress = goal > 0 ? min(1.0, current / goal) : 0

        return VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .font(.subheadline)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(String(format: "%.0f", current))
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                    Text(String(format: " / %.0f%@", goal, unit))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 8)

                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * progress), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Deficit/Surplus Messages

    @ViewBuilder
    private var deficitMessages: some View {
        let proteinDiff = log.totalProtein - profile.proteinGoal
        let carbsDiff = log.totalCarbs - profile.carbsGoal
        let fatDiff = log.totalFat - profile.fatGoal

        VStack(spacing: 6) {
            if profile.proteinGoal > 0 {
                if proteinDiff < 0 {
                    deficitRow(text: "Ti mancano \(String(format: "%.0f", abs(proteinDiff)))g di proteine", color: .biteBlue)
                } else if proteinDiff > 10 {
                    deficitRow(text: "Hai superato le proteine di \(String(format: "%.0f", proteinDiff))g", color: .biteBlue)
                }
            }
            if profile.carbsGoal > 0 && carbsDiff > 10 {
                deficitRow(text: "Hai superato i carboidrati di \(String(format: "%.0f", carbsDiff))g", color: .biteOrange)
            }
            if profile.fatGoal > 0 && fatDiff > 5 {
                deficitRow(text: "Hai superato i grassi di \(String(format: "%.0f", fatDiff))g", color: .biteRed)
            }
        }
    }

    private func deficitRow(text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: .rect(cornerRadius: 10))
    }

    // MARK: - Food List

    private var foodListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Alimenti")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(log.entries.count) registrati")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if log.entries.isEmpty {
                Text("Nessun alimento registrato")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(log.entries) { entry in
                        HStack {
                            Text(entry.text)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            if let nutrition = entry.nutrition {
                                Text("\(nutrition.calories) kcal")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)

                        if entry.id != log.entries.last?.id {
                            Divider().padding(.horizontal, 14)
                        }
                    }
                }
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            }
        }
    }

    // MARK: - Micro nutrients

    private var microSection: some View {
        let allEntries = log.entries.filter { $0.nutrition != nil }
        let totalFiber = allEntries.compactMap(\.nutrition?.fiber).reduce(0, +)
        let totalSugar = allEntries.compactMap(\.nutrition?.sugar).reduce(0, +)
        let totalSodium = allEntries.compactMap(\.nutrition?.sodium).reduce(0, +)

        let hasMicros = totalFiber > 0 || totalSugar > 0 || totalSodium > 0

        return Group {
            if hasMicros {
                VStack(spacing: 10) {
                    HStack {
                        Text("Dettagli")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        if totalFiber > 0 {
                            microRow(label: "Fibre", value: totalFiber, unit: "g")
                        }
                        if totalSugar > 0 {
                            microRow(label: "Zuccheri", value: totalSugar, unit: "g")
                        }
                        if totalSodium > 0 {
                            microRow(label: "Sodio", value: totalSodium, unit: "mg")
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            }
        }
    }

    private func microRow(label: String, value: Double, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f %@", value, unit))
                .font(.subheadline.weight(.medium))
                .fontDesign(.rounded)
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            DayDetailSheet(
                profile: .default,
                log: DayLog(
                    date: Date(),
                    entries: [
                        FoodEntry(
                            text: "Pasta carbonara",
                            nutrition: NutritionInfo(calories: 480, protein: 20, carbs: 55, fat: 20, fiber: 2, sugar: 2, sodium: 620)
                        ),
                        FoodEntry(
                            text: "Cappuccino",
                            nutrition: NutritionInfo(calories: 120, protein: 6, carbs: 10, fat: 6)
                        )
                    ]
                )
            )
        }
}
