import Foundation
import SwiftData

/// Owns the application-wide `ModelContainer` for SwiftData.
@MainActor
enum BiteModelContainer {
    static let schema = Schema([
        SDUserProfile.self,
        SDFoodEntry.self,
        SDWeightEntry.self,
        SDSavedFoodEntry.self,
        SDActivityStatus.self,
        SDDrinkEntry.self,
        SDCycleEntry.self,
        SDSmartAlarm.self,
        SDStrengthSession.self,
        SDStrengthSet.self,
        SDCustomExercise.self,
        BiologicalAgeSnapshot.self,
        SDJournalTag.self,
        CoachThread.self,
        CoachMessage.self,
        ArtifactMessage.self,
        CoachMemory.self,
        CoachNote.self,
        CoachPlan.self,
        WorkoutArtifactModel.self,
        Biomarker.self,
        LabReport.self,
        CheckInSchedule.self,
        SDFile.self,
    ])

    static let shared: ModelContainer = {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
