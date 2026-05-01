import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var draftProfile: UserProfile
    var weightEntries: [WeightEntry] = []
    var savedEntries: [FoodEntry] = []
    var showSavedToast = false

    private var saveTask: Task<Void, Never>?
    private let storage = StorageService.shared
    var onProfileUpdate: ((UserProfile) -> Void)?

    var savedMealsCount: Int { savedEntries.count }

    var lastWeight: Double? {
        weightEntries.last?.weightKg
    }

    var monthlyWeightChange: Double? {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentEntries = weightEntries.filter { $0.date >= thirtyDaysAgo }
        guard let first = recentEntries.first, let last = recentEntries.last, first.id != last.id else { return nil }
        return last.weightKg - first.weightKg
    }

    var dailyBurn: Int? {
        draftProfile.estimatedTDEE
    }

    init(profile: UserProfile) {
        self.draftProfile = profile
        self.weightEntries = storage.loadWeightEntries()
        self.savedEntries = storage.loadSavedEntries()
    }

    func debounceSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            storage.saveProfile(draftProfile)
            onProfileUpdate?(draftProfile)

            withAnimation(.easeInOut(duration: 0.3)) {
                showSavedToast = true
            }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showSavedToast = false
            }
        }
    }

    func addWeightEntry(kg: Double) {
        let entry = WeightEntry(weightKg: kg)
        storage.addWeightEntry(entry)
        weightEntries = storage.loadWeightEntries()
    }

    func clearLocalCache() {
        storage.clearLocalCache()
    }

    func exportData() -> Data {
        storage.exportAllData()
    }

    func deleteAccount() {
        storage.clearLocalCache()
    }

    func removeSavedEntry(_ entry: FoodEntry) {
        savedEntries.removeAll { $0.id == entry.id }
        storage.saveSavedEntries(savedEntries)
    }
}
