import Foundation
import SwiftData

enum JournalContributorKind: String, Codable, CaseIterable, Identifiable {
    case alcohol
    case symptom
    case medication
    case supplement
    case note
    case mood
    case stress

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alcohol: return "Alcohol"
        case .symptom: return "Symptom"
        case .medication: return "Medication"
        case .supplement: return "Supplement"
        case .note: return "Note"
        case .mood: return "Mood"
        case .stress: return "Stress"
        }
    }

    var defaultUnit: String {
        switch self {
        case .alcohol: return "drinks"
        case .symptom, .mood, .stress: return "/10"
        case .medication, .supplement, .note: return ""
        }
    }
}

@Model
final class SDJournalEntry {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var date: Date
    var value: Double?
    var unit: String?
    var note: String
    var source: String
    var createdAt: Date

    var kind: JournalContributorKind {
        get { JournalContributorKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        kind: JournalContributorKind,
        date: Date = Date(),
        value: Double? = nil,
        unit: String? = nil,
        note: String = "",
        source: String = "manual",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.date = date
        self.value = value
        self.unit = unit
        self.note = note
        self.source = source
        self.createdAt = createdAt
    }
}
