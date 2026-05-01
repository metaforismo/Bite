import Foundation
import SwiftUI

/// Discrete onboarding pages. The orchestrator switches on the current case
/// rather than a numeric index so we can dynamically include/exclude pages
/// (e.g., cycle tracking only when gender == female) without shifting indices.
enum OnboardingPage: Hashable, CaseIterable {
    case welcome
    case healthKit
    case notifications
    case microphone
    case camera
    case name
    case gender
    case age
    case height
    case weight
    case targetWeight
    case activityLevel
    case dietaryPreferences
    case allergies
    case hydrationGoal
    case caffeineLimit
    case sleepTarget
    case strengthExperience
    case cycleTracking
    case activityStatusBaseline
    case lifestyleInputs
    case calorieBias
    case journalTagsIntro
    case personality
    case widgetsTeaser
    case goalSummary
}

@MainActor
@Observable
final class OnboardingViewModel {
    // MARK: - State
    var currentPage: Int = 0

    // Goals + macros (V1)
    var name: String = ""
    var calorieGoal: String = "2000"
    var proteinGoal: String = "150"
    var carbsGoal: String = "250"
    var fatGoal: String = "65"

    // Body metrics (V1)
    var gender: Gender?
    var age: String = ""
    var heightCm: String = ""
    var weightKg: String = ""
    var targetWeightKg: String = ""
    var activityLevel: ActivityLevel = .moderatelyActive
    var calorieBias: CalorieBias = .neutral
    var healthKitAuthorized: Bool = false

    // V2 fields
    var dietaryPreferenceSet: Set<DietaryPreference> = []
    var allergiesSet: Set<String> = []
    var hydrationGoalML: Double = 2500
    var caffeineLimitMg: Double = 400
    var sleepTargetWakeTime: Date?
    var sleepTargetHours: Int = 8
    var strengthExperience: StrengthExperience = .beginner
    var cycleTrackingEnabled: Bool = false
    var activityStatusBaseline: ActivityStatusKind = .active
    var smokingStatus: SmokingStatus?
    var alcoholFrequency: AlcoholFrequency?
    var supplementsSet: Set<String> = []
    var coachPersonality: CoachPersonality = .friend

    private let storage = StorageService.shared

    // MARK: - Page list

    /// The active page sequence — gender-conditional pages only appear when relevant.
    var pages: [OnboardingPage] {
        var list: [OnboardingPage] = [
            .welcome,
            .healthKit,
            .notifications,
            .microphone,
            .camera,
            .name,
            .gender,
            .age,
            .height,
            .weight,
            .targetWeight,
            .activityLevel,
            .dietaryPreferences,
            .allergies,
            .hydrationGoal,
            .caffeineLimit,
            .sleepTarget,
            .strengthExperience,
        ]

        if gender == .female {
            list.append(.cycleTracking)
        }

        list += [
            .activityStatusBaseline,
            .lifestyleInputs,
            .calorieBias,
            .journalTagsIntro,
            .personality,
            .widgetsTeaser,
            .goalSummary,
        ]

        return list
    }

    var totalPages: Int { pages.count }

    var currentPageIdentifier: OnboardingPage {
        guard currentPage >= 0, currentPage < pages.count else { return .welcome }
        return pages[currentPage]
    }

    // MARK: - Validation

    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isGoalsValid: Bool {
        Int(calorieGoal) != nil && (Int(calorieGoal) ?? 0) > 0
    }

    var canProceed: Bool {
        switch currentPageIdentifier {
        case .name: return isNameValid
        case .goalSummary: return isGoalsValid
        default: return true
        }
    }

    var suggestedCalories: Int? {
        guard let gender = gender,
              let ageValue = Int(age), ageValue > 0,
              let height = Double(heightCm), height > 0,
              let weight = Double(weightKg), weight > 0 else {
            return nil
        }

        let bmr: Double
        switch gender {
        case .male:
            bmr = 10 * weight + 6.25 * height - 5 * Double(ageValue) + 5
        case .female:
            bmr = 10 * weight + 6.25 * height - 5 * Double(ageValue) - 161
        case .other, .preferNotToSay:
            bmr = 10 * weight + 6.25 * height - 5 * Double(ageValue) - 78
        }

        let tdee = bmr * activityLevel.multiplier * calorieBias.multiplier
        return Int(tdee.rounded())
    }

    var suggestedMacros: (protein: Int, carbs: Int, fat: Int)? {
        guard let tdee = suggestedCalories else { return nil }
        let protein = Int((Double(tdee) * 0.30 / 4).rounded())
        let carbs = Int((Double(tdee) * 0.45 / 4).rounded())
        let fat = Int((Double(tdee) * 0.25 / 9).rounded())
        return (protein, carbs, fat)
    }

    // MARK: - Navigation

    func nextPage() {
        guard currentPage < pages.count - 1 else { return }
        autoPopulateGoalsIfNeeded()
        BiteHaptics.selection()
        withAnimation(BiteMotion.onboardingPage) {
            currentPage += 1
        }
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        BiteHaptics.selection()
        withAnimation(BiteMotion.onboardingPage) {
            currentPage -= 1
        }
    }

    func autoPopulateGoalsIfNeeded() {
        if let tdee = suggestedCalories {
            calorieGoal = "\(tdee)"
        }
        if let macros = suggestedMacros {
            proteinGoal = "\(macros.protein)"
            carbsGoal = "\(macros.carbs)"
            fatGoal = "\(macros.fat)"
        }
    }

    func autoPopulateFromHealthKit() async {
        let healthKit = HealthKitService.shared

        if let weight = await healthKit.fetchLatestWeight() {
            weightKg = String(format: "%.1f", weight)
        }
        if let height = await healthKit.fetchLatestHeight() {
            heightCm = String(format: "%.0f", height)
        }
    }

    /// Gender defaults the cycle-tracking opt-in to true so the conditional page
    /// has a sensible starting state.
    func updateGender(_ value: Gender?) {
        gender = value
        if value == .female, !cycleTrackingEnabled {
            cycleTrackingEnabled = true
        }
    }

    // MARK: - Completion

    func completeOnboarding() async -> UserProfile {
        var profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            calorieGoal: Int(calorieGoal) ?? 2000,
            proteinGoal: Double(proteinGoal) ?? 150,
            carbsGoal: Double(carbsGoal) ?? 250,
            fatGoal: Double(fatGoal) ?? 65,
            hasCompletedOnboarding: true,
            gender: gender,
            age: Int(age),
            heightCm: Double(heightCm),
            weightKg: Double(weightKg),
            targetWeightKg: Double(targetWeightKg),
            activityLevel: activityLevel,
            calorieBias: calorieBias
        )

        // V2 fields
        profile.dietaryPreferences = Array(dietaryPreferenceSet)
        profile.allergies = Array(allergiesSet).sorted()
        profile.hydrationGoalML = hydrationGoalML
        profile.caffeineLimitMg = caffeineLimitMg
        profile.sleepTargetWakeTime = sleepTargetWakeTime
        profile.sleepTargetHours = sleepTargetHours
        profile.strengthExperience = strengthExperience
        profile.cycleTrackingEnabled = cycleTrackingEnabled
        profile.smokingStatus = smokingStatus
        profile.alcoholFrequency = alcoholFrequency
        profile.supplements = Array(supplementsSet).sorted()
        profile.coachPersonality = coachPersonality

        storage.saveProfile(profile)
        storage.seedActivityStatusIfMissing(activityStatusBaseline)
        return profile
    }
}
