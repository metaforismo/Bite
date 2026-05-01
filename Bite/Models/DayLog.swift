import Foundation

nonisolated struct DayLog: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    var entries: [FoodEntry]

    init(id: UUID = UUID(), date: Date = Date(), entries: [FoodEntry] = []) {
        self.id = id
        self.date = date
        self.entries = entries
    }

    var totalCalories: Int {
        entries.compactMap(\.nutrition?.calories).reduce(0, +)
    }

    var totalProtein: Double {
        entries.compactMap(\.nutrition?.protein).reduce(0, +)
    }

    var totalCarbs: Double {
        entries.compactMap(\.nutrition?.carbs).reduce(0, +)
    }

    var totalFat: Double {
        entries.compactMap(\.nutrition?.fat).reduce(0, +)
    }

    var totalFiber: Double {
        entries.compactMap(\.nutrition?.fiber).reduce(0, +)
    }

    var totalSugar: Double {
        entries.compactMap(\.nutrition?.sugar).reduce(0, +)
    }

    var totalSodium: Double {
        entries.compactMap(\.nutrition?.sodium).reduce(0, +)
    }
}
