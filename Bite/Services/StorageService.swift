import Foundation
import SwiftData

/// SwiftData-backed storage with the same public API the rest of the app already uses.
/// The first launch after the SwiftData migration runs `legacyMigrateIfNeeded()` which
/// reads the previous UserDefaults JSON blobs and rewrites them into SwiftData. The
/// UserDefaults keys are kept around as a recovery path for two app versions.
@MainActor
final class StorageService {
    static let shared = StorageService()

    private let userDefaults = UserDefaults.standard
    private let profileKey = "bite_user_profile"
    private let logsKey = "bite_day_logs"
    private let savedEntriesKey = "bite_saved_entries"
    private let weightEntriesKey = "bite_weight_entries"
    private let migrationDoneKey = "bite_swiftdata_migration_done_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var ctx: ModelContext { BiteModelContainer.shared.mainContext }

    private init() {
        legacyMigrateIfNeeded()
    }

    // MARK: - User Profile

    func saveProfile(_ profile: UserProfile) {
        do {
            if let existing = try ctx.fetch(FetchDescriptor<SDUserProfile>()).first {
                existing.update(from: profile)
            } else {
                ctx.insert(SDUserProfile(profile: profile))
            }
            try ctx.save()
        } catch {
            assertionFailure("saveProfile failed: \(error)")
        }
    }

    func loadProfile() -> UserProfile {
        do {
            if let row = try ctx.fetch(FetchDescriptor<SDUserProfile>()).first {
                return row.toStruct()
            }
        } catch {
            assertionFailure("loadProfile failed: \(error)")
        }
        return .default
    }

    // MARK: - Day Logs

    func saveDayLog(_ log: DayLog) {
        let day = Calendar.current.startOfDay(for: log.date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        do {
            // Fetch existing entries for this day, then reconcile.
            var existing = try ctx.fetch(FetchDescriptor<SDFoodEntry>(predicate: #Predicate { $0.dayStart >= day && $0.dayStart < nextDay }))
            let incomingIds = Set(log.entries.map(\.id))

            // Delete entries that were removed.
            for row in existing where !incomingIds.contains(row.id) {
                ctx.delete(row)
            }
            existing.removeAll { !incomingIds.contains($0.id) }
            let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

            for entry in log.entries {
                if let row = existingById[entry.id] {
                    row.update(from: entry)
                } else {
                    ctx.insert(SDFoodEntry(entry: entry))
                }
            }
            try ctx.save()
            if Calendar.current.isDateInToday(log.date) {
                refreshWidgetSnapshot(with: log)
            }
        } catch {
            assertionFailure("saveDayLog failed: \(error)")
        }
    }

    private func refreshWidgetSnapshot(with log: DayLog) {
        let profile = loadProfile()
        var snapshot = BiteWidgetSnapshot.load()
        snapshot.refreshedAt = Date()
        snapshot.consumedCalories = log.entries.compactMap(\.nutrition?.calories).reduce(0, +)
        snapshot.calorieGoal = profile.calorieGoal
        snapshot.protein = log.entries.compactMap(\.nutrition?.protein).reduce(0, +)
        snapshot.carbs = log.entries.compactMap(\.nutrition?.carbs).reduce(0, +)
        snapshot.fat = log.entries.compactMap(\.nutrition?.fat).reduce(0, +)
        snapshot.fiber = log.entries.compactMap(\.nutrition?.fiber).reduce(0, +)
        snapshot.nutritionPercent = profile.calorieGoal > 0
            ? min(1, Double(snapshot.consumedCalories) / Double(profile.calorieGoal))
            : 0
        WidgetSnapshotService.write(snapshot)
    }

    func loadDayLog(for date: Date) -> DayLog {
        let day = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        do {
            var descriptor = FetchDescriptor<SDFoodEntry>(predicate: #Predicate { $0.dayStart >= day && $0.dayStart < nextDay },
                                                          sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            descriptor.relationshipKeyPathsForPrefetching = []
            let rows = try ctx.fetch(descriptor)
            return DayLog(date: day, entries: rows.map { $0.toStruct() })
        } catch {
            assertionFailure("loadDayLog failed: \(error)")
            return DayLog(date: day)
        }
    }

    func loadAllLogs() -> [DayLog] {
        do {
            let rows = try ctx.fetch(FetchDescriptor<SDFoodEntry>(sortBy: [SortDescriptor(\.dayStart, order: .forward)]))
            let grouped = Dictionary(grouping: rows, by: \.dayStart)
            return grouped
                .map { DayLog(date: $0.key, entries: $0.value.sorted { $0.createdAt < $1.createdAt }.map { $0.toStruct() }) }
                .sorted { $0.date < $1.date }
        } catch {
            assertionFailure("loadAllLogs failed: \(error)")
            return []
        }
    }

    // MARK: - Saved Entries

    func saveSavedEntries(_ entries: [FoodEntry]) {
        do {
            let existing = try ctx.fetch(FetchDescriptor<SDSavedFoodEntry>())
            for row in existing { ctx.delete(row) }
            for entry in entries {
                ctx.insert(SDSavedFoodEntry(entry: entry))
            }
            try ctx.save()
        } catch {
            assertionFailure("saveSavedEntries failed: \(error)")
        }
    }

    func loadSavedEntries() -> [FoodEntry] {
        do {
            let rows = try ctx.fetch(FetchDescriptor<SDSavedFoodEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            return rows.map { $0.toStruct() }
        } catch {
            assertionFailure("loadSavedEntries failed: \(error)")
            return []
        }
    }

    // MARK: - Weight Entries

    func saveWeightEntries(_ entries: [WeightEntry]) {
        do {
            let existing = try ctx.fetch(FetchDescriptor<SDWeightEntry>())
            for row in existing { ctx.delete(row) }
            for entry in entries {
                ctx.insert(SDWeightEntry(entry: entry))
            }
            try ctx.save()
        } catch {
            assertionFailure("saveWeightEntries failed: \(error)")
        }
    }

    func loadWeightEntries() -> [WeightEntry] {
        do {
            let rows = try ctx.fetch(FetchDescriptor<SDWeightEntry>(sortBy: [SortDescriptor(\.date, order: .forward)]))
            return rows.map { $0.toStruct() }
        } catch {
            assertionFailure("loadWeightEntries failed: \(error)")
            return []
        }
    }

    func addWeightEntry(_ entry: WeightEntry) {
        ctx.insert(SDWeightEntry(entry: entry))
        try? ctx.save()
    }

    // MARK: - Activity Status

    func currentActivityStatus() -> SDActivityStatus? {
        do {
            var descriptor = FetchDescriptor<SDActivityStatus>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
            descriptor.fetchLimit = 1
            return try ctx.fetch(descriptor).first
        } catch {
            assertionFailure("currentActivityStatus failed: \(error)")
            return nil
        }
    }

    func setActivityStatus(_ kind: ActivityStatusKind, startedAt: Date = Date(), note: String? = nil) {
        ctx.insert(SDActivityStatus(kind: kind, startedAt: startedAt, note: note))
        try? ctx.save()
    }

    /// Idempotent — if no status row exists yet, write one with the given kind.
    /// Used by onboarding completion so a brand-new install has a baseline state.
    func seedActivityStatusIfMissing(_ kind: ActivityStatusKind) {
        if currentActivityStatus() == nil {
            setActivityStatus(kind)
        }
    }

    // MARK: - System Actions

    func clearLocalCache() {
        let keys = [profileKey, logsKey, savedEntriesKey, weightEntriesKey]
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
        do {
            for type in [
                SDUserProfile.self,
                SDFoodEntry.self,
                SDWeightEntry.self,
                SDSavedFoodEntry.self,
            ] as [any PersistentModel.Type] {
                try _eraseAll(type)
            }
            try ctx.save()
        } catch {
            assertionFailure("clearLocalCache failed: \(error)")
        }
    }

    private func _eraseAll<T: PersistentModel>(_ type: T.Type) throws {
        let rows = try ctx.fetch(FetchDescriptor<T>())
        for row in rows { ctx.delete(row) }
    }

    func exportAllData() -> Data {
        struct ExportPayload: Codable {
            let profile: UserProfile
            let logs: [DayLog]
            let savedEntries: [FoodEntry]
            let weightEntries: [WeightEntry]
            let exportDate: Date
        }
        let payload = ExportPayload(
            profile: loadProfile(),
            logs: loadAllLogs(),
            savedEntries: loadSavedEntries(),
            weightEntries: loadWeightEntries(),
            exportDate: Date()
        )
        return (try? encoder.encode(payload)) ?? Data()
    }

    // MARK: - Legacy migration

    /// One-shot migration from UserDefaults JSON to SwiftData.
    /// Idempotent — once `migrationDoneKey` is set, this is a no-op. Runs synchronously
    /// at app launch via the singleton init; UserDefaults survives so a future version
    /// could roll back if needed.
    private func legacyMigrateIfNeeded() {
        guard !userDefaults.bool(forKey: migrationDoneKey) else { return }

        // Profile
        if let data = userDefaults.data(forKey: profileKey),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            ctx.insert(SDUserProfile(profile: profile))
        }
        // Day logs
        if let data = userDefaults.data(forKey: logsKey),
           let logs = try? decoder.decode([DayLog].self, from: data) {
            for log in logs {
                for entry in log.entries {
                    ctx.insert(SDFoodEntry(entry: entry))
                }
            }
        }
        // Saved entries
        if let data = userDefaults.data(forKey: savedEntriesKey),
           let entries = try? decoder.decode([FoodEntry].self, from: data) {
            for entry in entries {
                ctx.insert(SDSavedFoodEntry(entry: entry))
            }
        }
        // Weight entries
        if let data = userDefaults.data(forKey: weightEntriesKey),
           let entries = try? decoder.decode([WeightEntry].self, from: data) {
            for entry in entries {
                ctx.insert(SDWeightEntry(entry: entry))
            }
        }
        try? ctx.save()
        userDefaults.set(true, forKey: migrationDoneKey)
    }
}
