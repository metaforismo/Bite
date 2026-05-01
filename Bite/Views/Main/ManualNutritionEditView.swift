import SwiftUI

struct ManualNutritionEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var description: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var sodium: String

    var onSave: (NutritionInfo, String) -> Void

    init(currentNutrition: NutritionInfo, currentDescription: String, onSave: @escaping (NutritionInfo, String) -> Void) {
        self.onSave = onSave
        _description = State(initialValue: currentDescription)
        _calories = State(initialValue: String(currentNutrition.calories))
        _protein = State(initialValue: String(format: "%.0f", currentNutrition.protein))
        _carbs = State(initialValue: String(format: "%.0f", currentNutrition.carbs))
        _fat = State(initialValue: String(format: "%.0f", currentNutrition.fat))
        _fiber = State(initialValue: currentNutrition.fiber.map { String(format: "%.0f", $0) } ?? "")
        _sugar = State(initialValue: currentNutrition.sugar.map { String(format: "%.0f", $0) } ?? "")
        _sodium = State(initialValue: currentNutrition.sodium.map { String(format: "%.0f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Descrizione") {
                    TextField("Cosa hai mangiato?", text: $description)
                }

                Section("Macronutrienti") {
                    numberRow(label: "Calorie", value: $calories, unit: "kcal")
                    numberRow(label: "Proteine", value: $protein, unit: "g")
                    numberRow(label: "Carboidrati", value: $carbs, unit: "g")
                    numberRow(label: "Grassi", value: $fat, unit: "g")
                }

                Section("Micronutrienti") {
                    numberRow(label: "Fibre", value: $fiber, unit: "g")
                    numberRow(label: "Zuccheri", value: $sugar, unit: "g")
                    numberRow(label: "Sodio", value: $sodium, unit: "mg")
                }
            }
            .navigationTitle("Modifica manuale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        let nutrition = NutritionInfo(
                            calories: Int(calories) ?? 0,
                            protein: Double(protein) ?? 0,
                            carbs: Double(carbs) ?? 0,
                            fat: Double(fat) ?? 0,
                            fiber: fiber.isEmpty ? nil : Double(fiber),
                            sugar: sugar.isEmpty ? nil : Double(sugar),
                            sodium: sodium.isEmpty ? nil : Double(sodium)
                        )
                        onSave(nutrition, description)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func numberRow(label: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
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
}
