import Foundation
import SwiftData

@Model
final class SDWeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKg: Double

    init(entry: WeightEntry) {
        self.id = entry.id
        self.date = entry.date
        self.weightKg = entry.weightKg
    }

    func toStruct() -> WeightEntry {
        WeightEntry(id: id, date: date, weightKg: weightKg)
    }
}
