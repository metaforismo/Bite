import Foundation
import SwiftUI

/// Discrete onboarding pages. The orchestrator switches on the current case
/// rather than a numeric index so we can dynamically include/exclude pages
/// (e.g., cycle tracking only when gender == female) without shifting indices.
enum OnboardingPage: Hashable, CaseIterable {
    case welcome
    case howItWorks
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

    private var isTransitioning = false

    private let storage = StorageService.shared
    private static let draftKey = "onboardingDraft"

    init() {
        restoreDraft()
    }

    // MARK: - Page list

    /// The active page sequence — gender-conditional pages only appear when relevant.
    var pages: [OnboardingPage] {
        var list: [OnboardingPage] = [
            .welcome,
            .howItWorks,
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

    /// Parses user-typed numbers tolerantly: EU decimal keyboards produce ","
    /// which `Double(_:)` rejects.
    static func parseDecimal(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    var suggestedCalories: Int? {
        guard let gender = gender,
              let ageValue = Int(age), ageValue > 0,
              let height = Self.parseDecimal(heightCm), height > 0,
              let weight = Self.parseDecimal(weightKg), weight > 0 else {
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

        var goalMultiplier = 1.0
        if let target = Self.parseDecimal(targetWeightKg), target > 0 {
            if target < weight - 1 {
                goalMultiplier = 0.85
            } else if target > weight + 1 {
                goalMultiplier = 1.10
            }
        }

        let tdee = bmr * activityLevel.multiplier * goalMultiplier * calorieBias.multiplier
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
        guard !isTransitioning, currentPage < pages.count - 1 else { return }
        isTransitioning = true
        clampNumericInputs()
        autoPopulateGoalsIfNeeded()
        BiteHaptics.selection()
        withAnimation(BiteMotion.onboardingPage) {
            currentPage += 1
        }
        saveDraft()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.isTransitioning = false
        }
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        BiteHaptics.selection()
        withAnimation(BiteMotion.onboardingPage) {
            currentPage -= 1
        }
    }

    /// Typed values get clamped to the same ranges the steppers enforce so a
    /// stray "7000" never reaches the calorie formula.
    private func clampNumericInputs() {
        switch currentPageIdentifier {
        case .age:
            if let value = Int(age) {
                let clamped = min(max(value, 16), 100)
                if clamped != value { age = "\(clamped)" }
            }
        case .height:
            if let value = Self.parseDecimal(heightCm) {
                let clamped = min(max(value, 100), 250)
                if clamped != value { heightCm = String(format: "%.0f", clamped) }
            }
        case .weight:
            if let value = Self.parseDecimal(weightKg) {
                let clamped = min(max(value, 30), 300)
                if clamped != value { weightKg = String(format: "%.1f", clamped) }
            }
        case .targetWeight:
            if let value = Self.parseDecimal(targetWeightKg) {
                let clamped = min(max(value, 30), 300)
                if clamped != value { targetWeightKg = String(format: "%.1f", clamped) }
            }
        default:
            break
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

    // MARK: - Draft persistence

    /// Lightweight snapshot of answered fields so a force-quit mid-flow
    /// doesn't throw away the user's progress.
    private struct OnboardingDraft: Codable {
        var currentPage: Int
        var name: String
        var gender: Gender?
        var age: String
        var heightCm: String
        var weightKg: String
        var targetWeightKg: String
        var activityLevel: ActivityLevel
        var calorieBias: CalorieBias
        var dietaryPreferences: [DietaryPreference]
        var allergies: [String]
        var hydrationGoalML: Double
        var caffeineLimitMg: Double
        var sleepTargetWakeTime: Date?
        var sleepTargetHours: Int
        var strengthExperience: StrengthExperience
        var cycleTrackingEnabled: Bool
        var activityStatusBaseline: ActivityStatusKind
        var smokingStatus: SmokingStatus?
        var alcoholFrequency: AlcoholFrequency?
        var supplements: [String]
        var coachPersonality: CoachPersonality
    }

    private func saveDraft() {
        let draft = OnboardingDraft(
            currentPage: currentPage,
            name: name,
            gender: gender,
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            targetWeightKg: targetWeightKg,
            activityLevel: activityLevel,
            calorieBias: calorieBias,
            dietaryPreferences: Array(dietaryPreferenceSet),
            allergies: Array(allergiesSet),
            hydrationGoalML: hydrationGoalML,
            caffeineLimitMg: caffeineLimitMg,
            sleepTargetWakeTime: sleepTargetWakeTime,
            sleepTargetHours: sleepTargetHours,
            strengthExperience: strengthExperience,
            cycleTrackingEnabled: cycleTrackingEnabled,
            activityStatusBaseline: activityStatusBaseline,
            smokingStatus: smokingStatus,
            alcoholFrequency: alcoholFrequency,
            supplements: Array(supplementsSet),
            coachPersonality: coachPersonality
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftKey)
    }

    private func restoreDraft() {
        guard let data = UserDefaults.standard.data(forKey: Self.draftKey),
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data) else { return }
        name = draft.name
        gender = draft.gender
        age = draft.age
        heightCm = draft.heightCm
        weightKg = draft.weightKg
        targetWeightKg = draft.targetWeightKg
        activityLevel = draft.activityLevel
        calorieBias = draft.calorieBias
        dietaryPreferenceSet = Set(draft.dietaryPreferences)
        allergiesSet = Set(draft.allergies)
        hydrationGoalML = draft.hydrationGoalML
        caffeineLimitMg = draft.caffeineLimitMg
        sleepTargetWakeTime = draft.sleepTargetWakeTime
        sleepTargetHours = draft.sleepTargetHours
        strengthExperience = draft.strengthExperience
        cycleTrackingEnabled = draft.cycleTrackingEnabled
        activityStatusBaseline = draft.activityStatusBaseline
        smokingStatus = draft.smokingStatus
        alcoholFrequency = draft.alcoholFrequency
        supplementsSet = Set(draft.supplements)
        coachPersonality = draft.coachPersonality
        currentPage = min(max(draft.currentPage, 0), pages.count - 1)
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }

    // MARK: - Completion

    func completeOnboarding() async -> UserProfile {
        var profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            calorieGoal: Int(calorieGoal) ?? 2000,
            proteinGoal: Self.parseDecimal(proteinGoal) ?? 150,
            carbsGoal: Self.parseDecimal(carbsGoal) ?? 250,
            fatGoal: Self.parseDecimal(fatGoal) ?? 65,
            hasCompletedOnboarding: true,
            gender: gender,
            age: Int(age),
            heightCm: Self.parseDecimal(heightCm),
            weightKg: Self.parseDecimal(weightKg),
            targetWeightKg: Self.parseDecimal(targetWeightKg),
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
        clearDraft()
        return profile
    }
}
