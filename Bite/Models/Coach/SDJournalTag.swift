import Foundation
import SwiftData

enum JournalTagCategory: String, Codable, CaseIterable, Sendable {
    case lifestyle
    case medical
    case healthStatus = "health_status"
    case supplements

    var displayName: String {
        switch self {
        case .lifestyle: return "Lifestyle"
        case .medical: return "Medical"
        case .healthStatus: return "Health status"
        case .supplements: return "Supplements"
        }
    }
}

@Model
final class SDJournalTag {
    @Attribute(.unique) var id: UUID
    /// References the underlying entry (food, weight, manual journal entry).
    var entryRefID: UUID
    var entryKind: String
    var tag: String
    var categoryRaw: String
    var source: String              // "auto" (worker) or "manual"
    var createdAt: Date

    init(
        id: UUID = UUID(),
        entryRefID: UUID,
        entryKind: String,
        tag: String,
        category: JournalTagCategory,
        source: String = "auto"
    ) {
        self.id = id
        self.entryRefID = entryRefID
        self.entryKind = entryKind
        self.tag = tag
        self.categoryRaw = category.rawValue
        self.source = source
        self.createdAt = Date()
    }

    var category: JournalTagCategory {
        JournalTagCategory(rawValue: categoryRaw) ?? .lifestyle
    }
}

/// Catalog of common habit tags Bite shows in the Insights view + the
/// Settings → Journal Tags screen. The user can toggle each one to opt out
/// of tracking. Worker-side classifier emits a subset of these tags per
/// food-entry / journal-entry.
enum JournalTagCatalog {
    struct Tag: Hashable, Identifiable {
        var id: String { name }
        let name: String
        let category: JournalTagCategory
    }

    static let all: [Tag] = [
        // Lifestyle
        Tag(name: "Late meal",       category: .lifestyle),
        Tag(name: "Alcohol",         category: .lifestyle),
        Tag(name: "Caffeine after 4pm", category: .lifestyle),
        Tag(name: "Heavy carb",      category: .lifestyle),
        Tag(name: "High protein",    category: .lifestyle),
        Tag(name: "Skipped meal",    category: .lifestyle),
        Tag(name: "Eating out",      category: .lifestyle),
        // Medical
        Tag(name: "Headache",        category: .medical),
        Tag(name: "Cramps",          category: .medical),
        Tag(name: "Brain fog",       category: .medical),
        Tag(name: "Stomach upset",   category: .medical),
        Tag(name: "Allergic flare",  category: .medical),
        // Health status
        Tag(name: "67+ nutrition score", category: .healthStatus),
        Tag(name: "10k+ steps",      category: .healthStatus),
        Tag(name: "20+ min cardio",  category: .healthStatus),
        Tag(name: "Strength session",category: .healthStatus),
        Tag(name: "Good sleep",      category: .healthStatus),
        // Supplements
        Tag(name: "Multivitamin",    category: .supplements),
        Tag(name: "Vitamin D",       category: .supplements),
        Tag(name: "Omega-3",         category: .supplements),
        Tag(name: "Creatine",        category: .supplements),
        Tag(name: "Magnesium",       category: .supplements),
        Tag(name: "Probiotic",       category: .supplements),
    ]

    static let userDefaultsKey = "bite_journal_tags_disabled"

    static func disabledSet() -> Set<String> {
        let raw = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
        return Set(raw)
    }

    static func setDisabled(_ disabled: Set<String>) {
        UserDefaults.standard.set(Array(disabled), forKey: userDefaultsKey)
    }
}
