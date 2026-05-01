import Foundation

nonisolated struct WeightEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let weightKg: Double

    init(id: UUID = UUID(), date: Date = Date(), weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }
}
