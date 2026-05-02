import SwiftUI
import Charts

struct NutritionGoalsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Form {
            // 1. Daily Burn
            if let tdee = vm.dailyBurn {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Consumo giornaliero stimato")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(tdee) kcal/giorno")
                                .font(.title2)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Your Daily Burn")
                }
            }

            // 2. Weight Goals
            Section {
                Picker("Obiettivo", selection: Bindable(vm).draftProfile.weightGoalType) {
                    ForEach(WeightGoalType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Label("Target weight", systemImage: "target")
                    Spacer()
                    TextField("—", text: Binding(
                        get: { vm.draftProfile.targetWeightKg.map { String(format: "%.1f", $0) } ?? "" },
                        set: { vm.draftProfile.targetWeightKg = Double($0) }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text("kg")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                DatePicker(
                    "Data obiettivo",
                    selection: Binding(
                        get: { vm.draftProfile.targetDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())! },
                        set: { vm.draftProfile.targetDate = $0 }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )
            } header: {
                Text("Obiettivo peso")
            }

            // 3. Weight Trajectory Chart
            if let current = vm.draftProfile.weightKg, let target = vm.draftProfile.targetWeightKg {
                Section {
                    weightTrajectoryChart(current: current, target: target)
                        .frame(height: 180)
                } header: {
                    Text("Traiettoria peso")
                }
            }

            // 4. Lifestyle & Dietary Preferences
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(DietaryPreference.allCases, id: \.self) { pref in
                        let isSelected = vm.draftProfile.dietaryPreferences.contains(pref)
                        Button {
                            if isSelected {
                                vm.draftProfile.dietaryPreferences.removeAll { $0 == pref }
                            } else {
                                vm.draftProfile.dietaryPreferences.append(pref)
                            }
                        } label: {
                            Text(pref.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(isSelected ? Color.biteRed.opacity(0.15) : Color.secondary.opacity(0.1), in: .capsule)
                                .foregroundStyle(isSelected ? Color.biteRed : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("Altro (allergie, preferenze...)", text: Bindable(vm).draftProfile.dietaryNotes)
                    .font(.subheadline)
            } header: {
                Text("Stile di vita & Preferenze")
            }

            // 5. Daily Nutrition Goals
            Section {
                goalRow(icon: "flame.fill", label: "Calories", value: Binding(
                    get: { String(vm.draftProfile.calorieGoal) },
                    set: { vm.draftProfile.calorieGoal = Int($0) ?? vm.draftProfile.calorieGoal }
                ), unit: "kcal", color: .biteOrange)

                goalRow(icon: "p.circle.fill", label: "Protein", value: Binding(
                    get: { String(format: "%.0f", vm.draftProfile.proteinGoal) },
                    set: { vm.draftProfile.proteinGoal = Double($0) ?? vm.draftProfile.proteinGoal }
                ), unit: "g", color: .biteBlue)

                goalRow(icon: "c.circle.fill", label: "Carbs", value: Binding(
                    get: { String(format: "%.0f", vm.draftProfile.carbsGoal) },
                    set: { vm.draftProfile.carbsGoal = Double($0) ?? vm.draftProfile.carbsGoal }
                ), unit: "g", color: .biteOrange)

                goalRow(icon: "f.circle.fill", label: "Fat", value: Binding(
                    get: { String(format: "%.0f", vm.draftProfile.fatGoal) },
                    set: { vm.draftProfile.fatGoal = Double($0) ?? vm.draftProfile.fatGoal }
                ), unit: "g", color: .biteRed)
            } header: {
                Text("Obiettivi giornalieri")
            }

            // 6. Micronutrients
            Section {
                microToggleRow(label: "Zuccheri", isTracking: Bindable(vm).draftProfile.trackSugar,
                              goal: Binding(
                                get: { vm.draftProfile.sugarGoal.map { String(format: "%.0f", $0) } ?? "" },
                                set: { vm.draftProfile.sugarGoal = Double($0) }
                              ), unit: "g", guide: "Raccomandato: < 25g/giorno (OMS)")

                microToggleRow(label: "Fibre", isTracking: Bindable(vm).draftProfile.trackFiber,
                              goal: Binding(
                                get: { vm.draftProfile.fiberGoal.map { String(format: "%.0f", $0) } ?? "" },
                                set: { vm.draftProfile.fiberGoal = Double($0) }
                              ), unit: "g", guide: "Raccomandato: 25-30g/giorno")

                microToggleRow(label: "Sodio", isTracking: Bindable(vm).draftProfile.trackSodium,
                              goal: Binding(
                                get: { vm.draftProfile.sodiumGoal.map { String(format: "%.0f", $0) } ?? "" },
                                set: { vm.draftProfile.sodiumGoal = Double($0) }
                              ), unit: "mg", guide: "Raccomandato: < 2300mg/giorno")
            } header: {
                Text("Micronutrienti")
            }
        }
        .navigationTitle("Obiettivi")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func goalRow(icon: String, label: String, value: Binding<String>, unit: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(color)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text(unit)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func microToggleRow(label: String, isTracking: Binding<Bool>, goal: Binding<String>, unit: String, guide: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(label, isOn: isTracking)

            if isTracking.wrappedValue {
                HStack {
                    TextField("Obiettivo", text: goal)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(guide)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func weightTrajectoryChart(current: Double, target: Double) -> some View {
        let today = Date()
        let targetDate = vm.draftProfile.targetDate ?? Calendar.current.date(byAdding: .month, value: 3, to: today)!

        let data: [(date: Date, weight: Double)] = [
            (today, current),
            (targetDate, target)
        ]

        Chart {
            ForEach(data, id: \.date) { point in
                LineMark(
                    x: .value("Data", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(Color.biteRed)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Data", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(Color.biteRed)
            }

            RuleMark(x: .value("Oggi", today))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(dash: [4, 4]))
        }
        .chartYScale(domain: min(current, target) - 2 ... max(current, target) + 2)
    }
}
