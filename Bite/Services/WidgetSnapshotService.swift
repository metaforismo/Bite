import Foundation
import WidgetKit

/// Snapshot of "Today at a glance" data shared with the BiteWidgets extension
/// via an App Group container. The main app rewrites this whenever Today
/// refreshes; widgets read it from `BiteWidgetSnapshot.load()`.
nonisolated struct BiteWidgetSnapshot: Codable, Sendable {
    var refreshedAt: Date
    var nutritionPercent: Double
    var recoveryPercent: Double
    var sleepPercent: Double
    var consumedCalories: Int
    var calorieGoal: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var hydrationML: Double
    var hydrationGoalML: Double
    var hrv: Double?
    var rhr: Double?

    static let appGroupID = "group.com.bite.health"
    static let snapshotFileName = "today_snapshot.json"

    static let empty = BiteWidgetSnapshot(
        refreshedAt: Date(),
        nutritionPercent: 0,
        recoveryPercent: 0,
        sleepPercent: 0,
        consumedCalories: 0,
        calorieGoal: 2000,
        protein: 0,
        carbs: 0,
        fat: 0,
        fiber: 0,
        hydrationML: 0,
        hydrationGoalML: 2500,
        hrv: nil,
        rhr: nil
    )

    static func load() -> BiteWidgetSnapshot {
        guard let url = sharedURL(),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(BiteWidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    static func sharedURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(snapshotFileName)
    }
}

/// Main-app side: writes the shared snapshot + nudges every widget timeline
/// to refresh.
@MainActor
enum WidgetSnapshotService {
    static func write(_ snapshot: BiteWidgetSnapshot) {
        guard let url = BiteWidgetSnapshot.sharedURL() else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // best-effort — widgets keep showing the previous snapshot
        }
    }

    /// Safe to call without an App Group set — `containerURL` returns nil.
    static func currentSnapshotPath() -> URL? {
        BiteWidgetSnapshot.sharedURL()
    }
}
