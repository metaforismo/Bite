import Foundation
import SwiftData

/// One logged drink — water or caffeinated. The same model handles both kinds
/// so the Today HydrationCard / CaffeineCard can run a single `@Query` and
/// filter by `kind`.
enum DrinkKind: String, Codable, CaseIterable, Sendable {
    case water
    case caffeine

    var displayName: String {
        switch self {
        case .water: return "Water"
        case .caffeine: return "Caffeine"
        }
    }
}

@Model
final class SDDrinkEntry {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var volumeML: Double?
    var caffeineMg: Double?
    var label: String?
    var timestamp: Date
    var dayStart: Date

    init(
        id: UUID = UUID(),
        kind: DrinkKind,
        volumeML: Double? = nil,
        caffeineMg: Double? = nil,
        label: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.volumeML = volumeML
        self.caffeineMg = caffeineMg
        self.label = label
        self.timestamp = timestamp
        self.dayStart = Calendar.current.startOfDay(for: timestamp)
    }

    var kind: DrinkKind {
        DrinkKind(rawValue: kindRaw) ?? .water
    }
}
