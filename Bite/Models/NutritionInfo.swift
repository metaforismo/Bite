import Foundation

nonisolated enum ConfidenceLevel: String, Codable, Sendable {
    case low, medium, high

    var label: String {
        switch self {
        case .low: return "Bassa"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }
}

nonisolated struct NutritionInfo: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    var confidenceLevel: ConfidenceLevel?

    var caloriesText: String {
        "\(calories) kcal"
    }

    init(
        id: UUID = UUID(),
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        sugar: Double? = nil,
        sodium: Double? = nil,
        confidenceLevel: ConfidenceLevel? = nil
    ) {
        self.id = id
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.confidenceLevel = confidenceLevel
    }
}
