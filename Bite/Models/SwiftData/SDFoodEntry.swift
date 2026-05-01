import Foundation
import SwiftData

@Model
final class SDFoodEntry {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date
    var dayStart: Date              // truncated start of `createdAt`'s local day, indexed for fast @Query

    var calories: Int?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    var confidenceLevelRaw: String?

    var aiThoughtProcess: String?
    var sources: [String]?
    var photoFileName: String?
    var correctionText: String?
    var isSaved: Bool
    var isLoading: Bool

    init(entry: FoodEntry) {
        self.id = entry.id
        self.text = entry.text
        self.createdAt = entry.createdAt
        self.dayStart = Calendar.current.startOfDay(for: entry.createdAt)
        self.calories = entry.nutrition?.calories
        self.protein = entry.nutrition?.protein
        self.carbs = entry.nutrition?.carbs
        self.fat = entry.nutrition?.fat
        self.fiber = entry.nutrition?.fiber
        self.sugar = entry.nutrition?.sugar
        self.sodium = entry.nutrition?.sodium
        self.confidenceLevelRaw = entry.nutrition?.confidenceLevel?.rawValue
        self.aiThoughtProcess = entry.aiThoughtProcess
        self.sources = entry.sources
        self.photoFileName = entry.photoFileName
        self.correctionText = entry.correctionText
        self.isSaved = entry.isSaved
        self.isLoading = entry.isLoading
    }

    func toStruct() -> FoodEntry {
        let nutrition: NutritionInfo? = {
            guard let calories, let protein, let carbs, let fat else { return nil }
            return NutritionInfo(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: fiber,
                sugar: sugar,
                sodium: sodium,
                confidenceLevel: confidenceLevelRaw.flatMap(ConfidenceLevel.init(rawValue:))
            )
        }()
        return FoodEntry(
            id: id,
            text: text,
            nutrition: nutrition,
            isLoading: isLoading,
            aiThoughtProcess: aiThoughtProcess,
            sources: sources,
            createdAt: createdAt,
            photoFileName: photoFileName,
            correctionText: correctionText,
            isSaved: isSaved
        )
    }

    func update(from entry: FoodEntry) {
        self.text = entry.text
        self.createdAt = entry.createdAt
        self.dayStart = Calendar.current.startOfDay(for: entry.createdAt)
        self.calories = entry.nutrition?.calories
        self.protein = entry.nutrition?.protein
        self.carbs = entry.nutrition?.carbs
        self.fat = entry.nutrition?.fat
        self.fiber = entry.nutrition?.fiber
        self.sugar = entry.nutrition?.sugar
        self.sodium = entry.nutrition?.sodium
        self.confidenceLevelRaw = entry.nutrition?.confidenceLevel?.rawValue
        self.aiThoughtProcess = entry.aiThoughtProcess
        self.sources = entry.sources
        self.photoFileName = entry.photoFileName
        self.correctionText = entry.correctionText
        self.isSaved = entry.isSaved
        self.isLoading = entry.isLoading
    }
}
