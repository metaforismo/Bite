import Foundation
import SwiftData

/// Mirrors Coach tool outcomes into local SwiftData so the data tabs
/// reflect Coach-driven changes immediately. The worker persists to D1;
/// iOS projects that state locally to drive the UI.
@MainActor
final class CoachToolDispatcher {
    static let shared = CoachToolDispatcher()

    private let storage = StorageService.shared

    private init() {}

    // MARK: - Food

    /// Append a Coach-extracted food entry to today's log.
    @discardableResult
    func mirrorFoodEntry(_ payload: FoodCartPayload, originatingArtifactId: UUID? = nil) -> CoachToolReceipt {
        let entry = FoodEntry(
            id: originatingArtifactId ?? UUID(),
            text: payload.dishName,
            nutrition: NutritionInfo(
                calories: payload.kcal,
                protein: payload.protein,
                carbs: payload.carbs,
                fat: payload.fat,
                fiber: payload.fiber
            ),
            createdAt: payload.mealAt ?? Date(),
            isSaved: false
        )
        let existing = storage.loadDayLog(for: entry.createdAt).entries
        let merged = existing.filter { $0.id != entry.id } + [entry]
        storage.saveDayLog(DayLog(date: entry.createdAt, entries: merged))

        return CoachToolReceipt(
            kind: .foodAdded,
            entryId: entry.id,
            affectedTab: .home,
            summary: "Added \(payload.dishName) · \(payload.kcal) kcal"
        )
    }

    @discardableResult
    func discardMirroredFood(entryId: UUID, on date: Date = Date()) -> CoachToolReceipt {
        let day = storage.loadDayLog(for: date)
        let filtered = day.entries.filter { $0.id != entryId }
        storage.saveDayLog(DayLog(date: day.date, entries: filtered))
        return CoachToolReceipt(
            kind: .foodDiscarded,
            entryId: entryId,
            affectedTab: .home,
            summary: "Removed from today's log"
        )
    }

    // MARK: - Drink

    @discardableResult
    func mirrorDrink(kind: DrinkKind, volumeMl: Double?, caffeineMg: Double?, label: String?) -> CoachToolReceipt {
        let entry = SDDrinkEntry(
            id: UUID(),
            kind: kind,
            volumeML: volumeMl,
            caffeineMg: caffeineMg,
            label: label,
            timestamp: Date()
        )
        BiteModelContainer.shared.mainContext.insert(entry)
        try? BiteModelContainer.shared.mainContext.save()

        let summary: String
        switch kind {
        case .water:
            summary = "Logged \(Int(volumeMl ?? 0))ml water"
        case .caffeine:
            summary = "Logged \(label ?? "caffeine") · \(Int(caffeineMg ?? 0))mg"
        }

        return CoachToolReceipt(
            kind: .drinkAdded,
            entryId: entry.id,
            affectedTab: .home,
            summary: summary
        )
    }

    // MARK: - Activity status

    @discardableResult
    func mirrorActivityStatus(kind: ActivityStatusKind, startedAt: Date = Date(), note: String? = nil) -> CoachToolReceipt {
        storage.setActivityStatus(kind, startedAt: startedAt, note: note)
        return CoachToolReceipt(
            kind: .activityStatusChanged,
            entryId: nil,
            affectedTab: .home,
            summary: "Status: \(kind.displayName)"
        )
    }

    // MARK: - Weight

    @discardableResult
    func mirrorWeight(weightKg: Double, recordedAt: Date = Date()) -> CoachToolReceipt {
        storage.addWeightEntry(WeightEntry(date: recordedAt, weightKg: weightKg))
        return CoachToolReceipt(
            kind: .weightLogged,
            entryId: nil,
            affectedTab: .home,
            summary: String(format: "Weight: %.1f kg", weightKg)
        )
    }

    // MARK: - Tool result router

    /// Decode a `tool_result` SSE event by name and dispatch to the right
    /// mirror method. Returns the receipt for the chat UI to surface.
    /// Food entries go through the artifact path instead — they need
    /// confirmation before mutating local state.
    func handleToolResult(name: String, resultJSON: String) -> CoachToolReceipt? {
        guard let data = resultJSON.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        switch name {
        case "addDrink":
            guard let r = try? decoder.decode(DrinkResult.self, from: data) else { return nil }
            let kind: DrinkKind = r.kind == "caffeine" ? .caffeine : .water
            return mirrorDrink(kind: kind, volumeMl: r.volumeMl, caffeineMg: r.caffeineMg, label: r.label)
        case "setActivityStatus":
            guard let r = try? decoder.decode(ActivityStatusResult.self, from: data) else { return nil }
            let kind = ActivityStatusKind(rawValue: r.kind == "on_break" ? "onBreak" : r.kind) ?? .active
            return mirrorActivityStatus(kind: kind, startedAt: Date(timeIntervalSince1970: r.startedAt / 1000), note: r.note)
        default:
            return nil
        }
    }

    // MARK: - Tool result decode types

    private struct DrinkResult: Decodable {
        let kind: String
        let volumeMl: Double?
        let caffeineMg: Double?
        let label: String?
    }

    private struct ActivityStatusResult: Decodable {
        let kind: String
        let startedAt: Double
        let note: String?
    }
}
