import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class DiaryViewModel {
    var currentLog: DayLog
    var selectedDate: Date
    var inputText: String = ""
    var isAnalyzing: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    var aiStatus: AIServiceStatus = .online

    // Saved entries
    var savedEntries: [FoodEntry] = []

    // Undo
    var recentlyDeletedEntry: FoodEntry?
    var showUndoToast: Bool = false
    private var undoTimer: Task<Void, Never>?

    private let aiService: any AIServiceProtocol
    private let storage = StorageService.shared
    private let photoStorage = PhotoStorageService.shared

    var filteredSuggestions: [FoodEntry] {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return savedEntries.filter { $0.text.lowercased().hasPrefix(query) }
    }

    init(aiService: (any AIServiceProtocol)? = nil, date: Date = Date()) {
        let service = aiService ?? MockAIService()
        self.aiService = service
        self.selectedDate = date
        self.currentLog = DayLog(date: date)
        self.savedEntries = storage.loadSavedEntries()
    }

    func loadDay() async {
        currentLog = storage.loadDayLog(for: selectedDate)
    }

    func changeDate(by days: Int) async {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = newDate
        await loadDay()
    }

    func changeDate(to date: Date) async {
        selectedDate = date
        await loadDay()
    }

    func addFoodEntry() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let entryId = UUID()
        var entry = FoodEntry(id: entryId, text: text, isLoading: true)

        currentLog.entries.append(entry)
        inputText = ""
        isAnalyzing = true

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        do {
            let (nutrition, thought, sources) = try await aiService.analyzeFoodEntry(text)
            guard !Task.isCancelled else { isAnalyzing = false; return }
            entry.nutrition = nutrition
            entry.aiThoughtProcess = thought
            entry.sources = sources
            entry.isLoading = false

            if let index = currentLog.entries.firstIndex(where: { $0.id == entryId }) {
                currentLog.entries[index] = entry
            }

            storage.saveDayLog(currentLog)
        } catch {
            entry.isLoading = false
            if let index = currentLog.entries.firstIndex(where: { $0.id == entryId }) {
                currentLog.entries[index] = entry
            }
            showErrorMessage(error.localizedDescription)
        }

        isAnalyzing = false
    }

    func addSavedEntry(_ entry: FoodEntry) {
        var newEntry = FoodEntry(
            text: entry.text,
            nutrition: entry.nutrition,
            aiThoughtProcess: entry.aiThoughtProcess,
            sources: entry.sources,
            isSaved: true
        )
        newEntry.isLoading = false
        currentLog.entries.append(newEntry)
        storage.saveDayLog(currentLog)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func addPhotoEntry(image: UIImage) async {
        guard let filename = photoStorage.savePhoto(image) else {
            showErrorMessage("Impossibile salvare la foto.")
            return
        }

        let entryId = UUID()
        var entry = FoodEntry(id: entryId, text: "Analisi in corso...", isLoading: true, photoFileName: filename)

        currentLog.entries.append(entry)
        isAnalyzing = true

        do {
            let (description, nutrition, thought, sources) = try await aiService.analyzePhoto(image, context: nil)
            guard !Task.isCancelled else { isAnalyzing = false; return }
            entry.text = description
            entry.nutrition = nutrition
            entry.aiThoughtProcess = thought
            entry.sources = sources
            entry.isLoading = false

            if let index = currentLog.entries.firstIndex(where: { $0.id == entryId }) {
                currentLog.entries[index] = entry
            }

            storage.saveDayLog(currentLog)
        } catch {
            entry.isLoading = false
            if let index = currentLog.entries.firstIndex(where: { $0.id == entryId }) {
                currentLog.entries[index] = entry
            }
            showErrorMessage(error.localizedDescription)
        }

        isAnalyzing = false
    }

    func correctEntry(_ entry: FoodEntry, correction: String) async {
        guard let index = currentLog.entries.firstIndex(where: { $0.id == entry.id }) else { return }

        currentLog.entries[index].isLoading = true
        currentLog.entries[index].correctionText = correction

        do {
            let (nutrition, thought, sources) = try await aiService.correctEntry(original: entry, correction: correction)
            guard !Task.isCancelled else { return }
            currentLog.entries[index].nutrition = nutrition
            currentLog.entries[index].aiThoughtProcess = thought
            currentLog.entries[index].sources = sources
            currentLog.entries[index].isLoading = false
            storage.saveDayLog(currentLog)
        } catch {
            currentLog.entries[index].isLoading = false
            showErrorMessage(error.localizedDescription)
        }
    }

    func manualEditEntry(_ entry: FoodEntry, nutrition: NutritionInfo, text: String) {
        guard let index = currentLog.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        currentLog.entries[index].nutrition = nutrition
        currentLog.entries[index].text = text
        currentLog.entries[index].correctionText = "Modifica manuale"
        storage.saveDayLog(currentLog)
    }

    func editEntryText(_ entry: FoodEntry, newText: String) async {
        guard let index = currentLog.entries.firstIndex(where: { $0.id == entry.id }) else { return }

        currentLog.entries[index].text = newText
        currentLog.entries[index].isLoading = true

        do {
            let (nutrition, thought, sources) = try await aiService.analyzeFoodEntry(newText)
            guard !Task.isCancelled else { return }
            currentLog.entries[index].nutrition = nutrition
            currentLog.entries[index].aiThoughtProcess = thought
            currentLog.entries[index].sources = sources
            currentLog.entries[index].isLoading = false
            storage.saveDayLog(currentLog)
        } catch {
            currentLog.entries[index].isLoading = false
            showErrorMessage(error.localizedDescription)
        }
    }

    func deleteEntry(_ entry: FoodEntry) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        recentlyDeletedEntry = entry
        currentLog.entries.removeAll { $0.id == entry.id }
        storage.saveDayLog(currentLog)

        showUndoToast = true
        undoTimer?.cancel()
        undoTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            // Only delete the photo file once the undo window has elapsed.
            if let photoFileName = self.recentlyDeletedEntry?.photoFileName {
                self.photoStorage.deletePhoto(named: photoFileName)
            }
            self.showUndoToast = false
            self.recentlyDeletedEntry = nil
        }
    }

    func undoDelete() {
        guard let entry = recentlyDeletedEntry else { return }
        // Photo file was never deleted (deferred), so the entry restores cleanly.
        currentLog.entries.append(entry)
        storage.saveDayLog(currentLog)
        recentlyDeletedEntry = nil
        showUndoToast = false
        undoTimer?.cancel()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func retryEntry(_ entry: FoodEntry) async {
        guard let index = currentLog.entries.firstIndex(where: { $0.id == entry.id }) else { return }

        currentLog.entries[index].isLoading = true

        do {
            let (nutrition, thought, sources) = try await aiService.analyzeFoodEntry(entry.text)
            guard !Task.isCancelled else { return }
            currentLog.entries[index].nutrition = nutrition
            currentLog.entries[index].aiThoughtProcess = thought
            currentLog.entries[index].sources = sources
            currentLog.entries[index].isLoading = false
            storage.saveDayLog(currentLog)
        } catch {
            currentLog.entries[index].isLoading = false
            showErrorMessage(error.localizedDescription)
        }
    }

    func toggleSaved(_ entry: FoodEntry) {
        guard let index = currentLog.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        currentLog.entries[index].isSaved.toggle()
        storage.saveDayLog(currentLog)

        if currentLog.entries[index].isSaved {
            var savedCopy = currentLog.entries[index]
            savedCopy.isLoading = false
            savedEntries.append(savedCopy)
        } else {
            savedEntries.removeAll { $0.id == entry.id }
        }
        storage.saveSavedEntries(savedEntries)
    }

    func removeSavedEntry(_ entry: FoodEntry) {
        savedEntries.removeAll { $0.id == entry.id }
        storage.saveSavedEntries(savedEntries)

        // Also unmark in current log if present
        if let index = currentLog.entries.firstIndex(where: { $0.id == entry.id }) {
            currentLog.entries[index].isSaved = false
            storage.saveDayLog(currentLog)
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
