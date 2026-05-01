import Foundation

/// Mirrors Coach tool outcomes (currently `food_cart` artifacts) into local
/// SwiftData so the data tabs (Today rings, Journal) reflect Coach-driven
/// changes immediately. The worker has already persisted to D1; iOS just
/// projects that state locally to drive the UI.
///
/// Phase 1 wires food entry mirroring. Future phases extend with drink,
/// activity, cycle, workout, weight, goal-change tools.
@MainActor
final class CoachToolDispatcher {
    static let shared = CoachToolDispatcher()

    private let storage = StorageService.shared

    private init() {}

    /// Append a Coach-extracted food entry to today's log. Returns a receipt
    /// the chat UI uses to render a "View in Today" affordance.
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
        // Idempotent: if an entry with the same id exists already, replace it
        // (handles correctFoodEntry artifact updates that re-render the same id).
        let merged = existing.filter { $0.id != entry.id } + [entry]
        storage.saveDayLog(DayLog(date: entry.createdAt, entries: merged))

        return CoachToolReceipt(
            kind: .foodAdded,
            entryId: entry.id,
            affectedTab: .home,
            summary: "Added \(payload.dishName) · \(payload.kcal) kcal"
        )
    }

    /// Remove a previously mirrored food entry. Used when the user discards a
    /// proposed entry — the worker D1 row remains; future cleanup tool can
    /// reconcile.
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
}
