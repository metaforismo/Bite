import Foundation
import SwiftData

@Model
final class SDUserProfile {
    /// Singleton key — there is exactly one user profile per app install.
    @Attribute(.unique) var key: String = "current"

    var name: String
    var calorieGoal: Int
    var proteinGoal: Double
    var carbsGoal: Double
    var fatGoal: Double
    var hasCompletedOnboarding: Bool

    var genderRaw: String?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var targetWeightKg: Double?
    var activityLevelRaw: String?
    var calorieBiasRaw: String?

    var email: String
    var useLocationForRestaurants: Bool
    var dailyRemindersEnabled: Bool
    var reminderFrequencyRaw: String
    var automaticTimeZone: Bool
    var dictationLanguageRaw: String

    var healthEnabled: Bool
    var healthSendCalories: Bool
    var healthSendMacros: Bool
    var healthReadBurnedCalories: Bool
    var healthReadRestingEnergy: Bool
    var healthReadSteps: Bool
    var healthReadWorkouts: Bool

    var trackSugar: Bool
    var trackFiber: Bool
    var trackSodium: Bool
    var sugarGoal: Double?
    var fiberGoal: Double?
    var sodiumGoal: Double?

    var dietaryPreferencesRaw: [String]
    var dietaryNotes: String
    var weightGoalTypeRaw: String
    var targetDate: Date?

    var coachPersonalityRaw: String?

    // V2 fields (default values mean older SwiftData stores upgrade transparently —
    // SwiftData adds the columns with defaults rather than running a custom migration)
    var allergiesRaw: [String] = []
    var hydrationGoalML: Double = 2500
    var caffeineLimitMg: Double = 400
    var cycleTrackingEnabled: Bool = false
    var weightUnitRaw: String = WeightUnit.kilograms.rawValue
    var sleepTargetWakeTime: Date?
    var sleepTargetHours: Int = 8
    var strengthExperienceRaw: String = StrengthExperience.beginner.rawValue
    var smokingStatusRaw: String?
    var alcoholFrequencyRaw: String?
    var supplementsRaw: [String] = []

    init(profile: UserProfile = .default) {
        self.name = profile.name
        self.calorieGoal = profile.calorieGoal
        self.proteinGoal = profile.proteinGoal
        self.carbsGoal = profile.carbsGoal
        self.fatGoal = profile.fatGoal
        self.hasCompletedOnboarding = profile.hasCompletedOnboarding
        self.genderRaw = profile.gender?.rawValue
        self.age = profile.age
        self.heightCm = profile.heightCm
        self.weightKg = profile.weightKg
        self.targetWeightKg = profile.targetWeightKg
        self.activityLevelRaw = profile.activityLevel?.rawValue
        self.calorieBiasRaw = profile.calorieBias?.rawValue
        self.email = profile.email
        self.useLocationForRestaurants = profile.useLocationForRestaurants
        self.dailyRemindersEnabled = profile.dailyRemindersEnabled
        self.reminderFrequencyRaw = profile.reminderFrequency.rawValue
        self.automaticTimeZone = profile.automaticTimeZone
        self.dictationLanguageRaw = profile.dictationLanguage.rawValue
        self.healthEnabled = profile.healthEnabled
        self.healthSendCalories = profile.healthSendCalories
        self.healthSendMacros = profile.healthSendMacros
        self.healthReadBurnedCalories = profile.healthReadBurnedCalories
        self.healthReadRestingEnergy = profile.healthReadRestingEnergy
        self.healthReadSteps = profile.healthReadSteps
        self.healthReadWorkouts = profile.healthReadWorkouts
        self.trackSugar = profile.trackSugar
        self.trackFiber = profile.trackFiber
        self.trackSodium = profile.trackSodium
        self.sugarGoal = profile.sugarGoal
        self.fiberGoal = profile.fiberGoal
        self.sodiumGoal = profile.sodiumGoal
        self.dietaryPreferencesRaw = profile.dietaryPreferences.map(\.rawValue)
        self.dietaryNotes = profile.dietaryNotes
        self.weightGoalTypeRaw = profile.weightGoalType.rawValue
        self.targetDate = profile.targetDate
        self.coachPersonalityRaw = profile.coachPersonality.rawValue
        self.allergiesRaw = profile.allergies
        self.hydrationGoalML = profile.hydrationGoalML
        self.caffeineLimitMg = profile.caffeineLimitMg
        self.cycleTrackingEnabled = profile.cycleTrackingEnabled
        self.weightUnitRaw = profile.weightUnit.rawValue
        self.sleepTargetWakeTime = profile.sleepTargetWakeTime
        self.sleepTargetHours = profile.sleepTargetHours
        self.strengthExperienceRaw = profile.strengthExperience.rawValue
        self.smokingStatusRaw = profile.smokingStatus?.rawValue
        self.alcoholFrequencyRaw = profile.alcoholFrequency?.rawValue
        self.supplementsRaw = profile.supplements
    }

    func toStruct() -> UserProfile {
        var p = UserProfile(
            name: name,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatGoal: fatGoal,
            hasCompletedOnboarding: hasCompletedOnboarding,
            gender: genderRaw.flatMap(Gender.init(rawValue:)),
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            targetWeightKg: targetWeightKg,
            activityLevel: activityLevelRaw.flatMap(ActivityLevel.init(rawValue:)),
            calorieBias: calorieBiasRaw.flatMap(CalorieBias.init(rawValue:))
        )
        p.email = email
        p.useLocationForRestaurants = useLocationForRestaurants
        p.dailyRemindersEnabled = dailyRemindersEnabled
        if let f = ReminderFrequency(rawValue: reminderFrequencyRaw) { p.reminderFrequency = f }
        p.automaticTimeZone = automaticTimeZone
        if let l = DictationLanguage(rawValue: dictationLanguageRaw) { p.dictationLanguage = l }
        p.healthEnabled = healthEnabled
        p.healthSendCalories = healthSendCalories
        p.healthSendMacros = healthSendMacros
        p.healthReadBurnedCalories = healthReadBurnedCalories
        p.healthReadRestingEnergy = healthReadRestingEnergy
        p.healthReadSteps = healthReadSteps
        p.healthReadWorkouts = healthReadWorkouts
        p.trackSugar = trackSugar
        p.trackFiber = trackFiber
        p.trackSodium = trackSodium
        p.sugarGoal = sugarGoal
        p.fiberGoal = fiberGoal
        p.sodiumGoal = sodiumGoal
        p.dietaryPreferences = dietaryPreferencesRaw.compactMap(DietaryPreference.init(rawValue:))
        p.dietaryNotes = dietaryNotes
        if let t = WeightGoalType(rawValue: weightGoalTypeRaw) { p.weightGoalType = t }
        p.targetDate = targetDate
        if let pers = coachPersonalityRaw.flatMap(CoachPersonality.init(rawValue:)) {
            p.coachPersonality = pers
        }
        p.allergies = allergiesRaw
        p.hydrationGoalML = hydrationGoalML
        p.caffeineLimitMg = caffeineLimitMg
        p.cycleTrackingEnabled = cycleTrackingEnabled
        if let unit = WeightUnit(rawValue: weightUnitRaw) { p.weightUnit = unit }
        p.sleepTargetWakeTime = sleepTargetWakeTime
        p.sleepTargetHours = sleepTargetHours
        if let exp = StrengthExperience(rawValue: strengthExperienceRaw) { p.strengthExperience = exp }
        p.smokingStatus = smokingStatusRaw.flatMap(SmokingStatus.init(rawValue:))
        p.alcoholFrequency = alcoholFrequencyRaw.flatMap(AlcoholFrequency.init(rawValue:))
        p.supplements = supplementsRaw
        return p
    }

    func update(from profile: UserProfile) {
        self.name = profile.name
        self.calorieGoal = profile.calorieGoal
        self.proteinGoal = profile.proteinGoal
        self.carbsGoal = profile.carbsGoal
        self.fatGoal = profile.fatGoal
        self.hasCompletedOnboarding = profile.hasCompletedOnboarding
        self.genderRaw = profile.gender?.rawValue
        self.age = profile.age
        self.heightCm = profile.heightCm
        self.weightKg = profile.weightKg
        self.targetWeightKg = profile.targetWeightKg
        self.activityLevelRaw = profile.activityLevel?.rawValue
        self.calorieBiasRaw = profile.calorieBias?.rawValue
        self.email = profile.email
        self.useLocationForRestaurants = profile.useLocationForRestaurants
        self.dailyRemindersEnabled = profile.dailyRemindersEnabled
        self.reminderFrequencyRaw = profile.reminderFrequency.rawValue
        self.automaticTimeZone = profile.automaticTimeZone
        self.dictationLanguageRaw = profile.dictationLanguage.rawValue
        self.healthEnabled = profile.healthEnabled
        self.healthSendCalories = profile.healthSendCalories
        self.healthSendMacros = profile.healthSendMacros
        self.healthReadBurnedCalories = profile.healthReadBurnedCalories
        self.healthReadRestingEnergy = profile.healthReadRestingEnergy
        self.healthReadSteps = profile.healthReadSteps
        self.healthReadWorkouts = profile.healthReadWorkouts
        self.trackSugar = profile.trackSugar
        self.trackFiber = profile.trackFiber
        self.trackSodium = profile.trackSodium
        self.sugarGoal = profile.sugarGoal
        self.fiberGoal = profile.fiberGoal
        self.sodiumGoal = profile.sodiumGoal
        self.dietaryPreferencesRaw = profile.dietaryPreferences.map(\.rawValue)
        self.dietaryNotes = profile.dietaryNotes
        self.weightGoalTypeRaw = profile.weightGoalType.rawValue
        self.targetDate = profile.targetDate
        self.coachPersonalityRaw = profile.coachPersonality.rawValue
        self.allergiesRaw = profile.allergies
        self.hydrationGoalML = profile.hydrationGoalML
        self.caffeineLimitMg = profile.caffeineLimitMg
        self.cycleTrackingEnabled = profile.cycleTrackingEnabled
        self.weightUnitRaw = profile.weightUnit.rawValue
        self.sleepTargetWakeTime = profile.sleepTargetWakeTime
        self.sleepTargetHours = profile.sleepTargetHours
        self.strengthExperienceRaw = profile.strengthExperience.rawValue
        self.smokingStatusRaw = profile.smokingStatus?.rawValue
        self.alcoholFrequencyRaw = profile.alcoholFrequency?.rawValue
        self.supplementsRaw = profile.supplements
    }
}
