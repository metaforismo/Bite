import Foundation
import SwiftData

/// One day of cycle data — flow level + symptoms. Sources include
/// HealthKit (menstrual_flow samples) and manual entries via MenstrualLogSheet.
/// The `date` is the start-of-day; one entry per (date, source).
@Model
final class SDCycleEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var flowLevel: Int       // 0 none / 1 light / 2 medium / 3 heavy
    var symptomsRaw: String  // comma-separated list (kept simple for V2)
    var source: String       // "healthkit" or "manual"

    init(
        id: UUID = UUID(),
        date: Date,
        flowLevel: Int,
        symptoms: [String] = [],
        source: String = "manual"
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.flowLevel = flowLevel
        self.symptomsRaw = symptoms.joined(separator: ",")
        self.source = source
    }

    var symptoms: [String] {
        get {
            symptomsRaw
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set { symptomsRaw = newValue.joined(separator: ",") }
    }

    var hasFlow: Bool { flowLevel > 0 }
}
