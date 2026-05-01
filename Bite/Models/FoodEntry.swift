import Foundation

nonisolated struct FoodEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String
    var nutrition: NutritionInfo?
    var isLoading: Bool
    var aiThoughtProcess: String?
    var sources: [String]?
    let createdAt: Date
    var photoFileName: String?
    var correctionText: String?
    var isSaved: Bool

    init(
        id: UUID = UUID(),
        text: String,
        nutrition: NutritionInfo? = nil,
        isLoading: Bool = false,
        aiThoughtProcess: String? = nil,
        sources: [String]? = nil,
        createdAt: Date = Date(),
        photoFileName: String? = nil,
        correctionText: String? = nil,
        isSaved: Bool = false
    ) {
        self.id = id
        self.text = text
        self.nutrition = nutrition
        self.isLoading = isLoading
        self.aiThoughtProcess = aiThoughtProcess
        self.sources = sources
        self.createdAt = createdAt
        self.photoFileName = photoFileName
        self.correctionText = correctionText
        self.isSaved = isSaved
    }
}
