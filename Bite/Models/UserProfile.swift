import Foundation

// MARK: - Enums (rawValues stay Italian for Codable back-compat with V1 stored profiles;
// `displayName` returns English labels for all UI. Add `.displayName` to new UI usages,
// never `.rawValue`.)

nonisolated enum Gender: String, Codable, CaseIterable, Sendable {
    case male = "Maschio"
    case female = "Femmina"
    case other = "Altro"
    case preferNotToSay = "Preferisco non specificare"

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

nonisolated enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary = "Sedentario"
    case lightlyActive = "Poco attivo"
    case moderatelyActive = "Moderatamente attivo"
    case veryActive = "Molto attivo"
    case extraActive = "Extra attivo"

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }

    var icon: String {
        switch self {
        case .sedentary: return "figure.stand"
        case .lightlyActive: return "figure.walk"
        case .moderatelyActive: return "figure.run"
        case .veryActive: return "figure.highintensity.intervaltraining"
        case .extraActive: return "figure.strengthtraining.traditional"
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly active"
        case .moderatelyActive: return "Moderately active"
        case .veryActive: return "Very active"
        case .extraActive: return "Extra active"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .lightlyActive: return "Light exercise 1–3×/week"
        case .moderatelyActive: return "Moderate exercise 3–5×/week"
        case .veryActive: return "Hard exercise 6–7×/week"
        case .extraActive: return "Very hard daily training"
        }
    }
}

nonisolated enum WeightGoalType: String, Codable, CaseIterable, Sendable {
    case lose = "Perdere peso"
    case maintain = "Mantenere"
    case gain = "Aumentare peso"

    var displayName: String {
        switch self {
        case .lose: return "Lose weight"
        case .maintain: return "Maintain"
        case .gain: return "Gain weight"
        }
    }
}

nonisolated enum DietaryPreference: String, Codable, CaseIterable, Sendable {
    // V1 cases (Italian rawValues kept for back-compat).
    case highProtein = "Alto contenuto proteico"
    case lowCarb = "Low carb"
    case athlete = "Atleta"
    case strengthTraining = "Allenamento forza"
    case enduranceTraining = "Allenamento resistenza"

    // V2 dietary-identity cases (English rawValues — new in V2).
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case pescatarian = "pescatarian"
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case keto = "keto"
    case mediterranean = "mediterranean"
    case otherDiet = "other_diet"

    var displayName: String {
        switch self {
        case .highProtein: return "High protein"
        case .lowCarb: return "Low carb"
        case .athlete: return "Athlete"
        case .strengthTraining: return "Strength training"
        case .enduranceTraining: return "Endurance training"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .glutenFree: return "Gluten-free"
        case .dairyFree: return "Dairy-free"
        case .keto: return "Keto"
        case .mediterranean: return "Mediterranean"
        case .otherDiet: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .highProtein: return "p.circle.fill"
        case .lowCarb: return "minus.circle.fill"
        case .athlete: return "figure.run"
        case .strengthTraining: return "figure.strengthtraining.traditional"
        case .enduranceTraining: return "figure.run.treadmill"
        case .vegetarian: return "leaf.fill"
        case .vegan: return "leaf.circle.fill"
        case .pescatarian: return "fish.fill"
        case .glutenFree: return "circle.slash"
        case .dairyFree: return "drop.degreesign.slash"
        case .keto: return "flame.fill"
        case .mediterranean: return "sun.max.fill"
        case .otherDiet: return "ellipsis.circle.fill"
        }
    }

    /// V2 onboarding shows the dietary-identity cases only (the V1 nutritional-approach
    /// cases stay decodable from older profiles but are no longer presented as choices).
    static var v2Choices: [DietaryPreference] {
        [.vegetarian, .vegan, .pescatarian, .glutenFree, .dairyFree, .keto, .mediterranean, .otherDiet]
    }
}

nonisolated enum ReminderFrequency: String, Codable, CaseIterable, Sendable {
    case once = "Una volta"
    case twice = "Due volte"
    case thrice = "Tre volte"

    var displayName: String {
        switch self {
        case .once: return "Once a day"
        case .twice: return "Twice a day"
        case .thrice: return "Three times a day"
        }
    }
}

nonisolated enum DictationLanguage: String, Codable, CaseIterable, Sendable {
    case auto = "Automatico"
    case english = "English"
    case spanish = "Español"
    case french = "Français"
    case german = "Deutsch"
    case portuguese = "Português"
    case italian = "Italiano"
    case dutch = "Nederlands"
    case russian = "Русский"
    case japanese = "日本語"
    case chinese = "中文"
    case korean = "한국어"

    var displayName: String {
        switch self {
        case .auto: return "Automatic"
        default: return rawValue
        }
    }
}

nonisolated enum CalorieBias: String, Codable, CaseIterable, Sendable {
    case overestimate = "Sovrastima"
    case neutral = "Neutro"
    case underestimate = "Sottostima"

    var multiplier: Double {
        switch self {
        case .overestimate: return 1.1
        case .neutral: return 1.0
        case .underestimate: return 0.9
        }
    }

    var displayName: String {
        switch self {
        case .overestimate: return "Overestimate"
        case .neutral: return "Neutral"
        case .underestimate: return "Underestimate"
        }
    }

    var description: String {
        switch self {
        case .overestimate: return "Round calorie estimates up for safety"
        case .neutral: return "Balanced, neutral estimates"
        case .underestimate: return "Round calorie estimates down"
        }
    }

    var icon: String {
        switch self {
        case .overestimate: return "arrow.up.circle.fill"
        case .neutral: return "equal.circle.fill"
        case .underestimate: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - V2 enums (English rawValues)

nonisolated enum WeightUnit: String, Codable, CaseIterable, Sendable {
    case kilograms = "kg"
    case pounds = "lb"

    var displayName: String { rawValue }
}

nonisolated enum StrengthExperience: String, Codable, CaseIterable, Sendable {
    case never = "never"
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var displayName: String {
        switch self {
        case .never: return "Never lifted"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .never: return "I've never trained with weights"
        case .beginner: return "Less than 1 year"
        case .intermediate: return "1–3 years of consistent training"
        case .advanced: return "3+ years, knows their numbers"
        }
    }

    var defaultRestSeconds: Int {
        switch self {
        case .never, .beginner: return 90
        case .intermediate: return 75
        case .advanced: return 60
        }
    }

    var icon: String {
        switch self {
        case .never: return "figure.walk"
        case .beginner: return "figure.flexibility"
        case .intermediate: return "figure.strengthtraining.functional"
        case .advanced: return "figure.strengthtraining.traditional"
        }
    }
}

nonisolated enum SmokingStatus: String, Codable, CaseIterable, Sendable {
    case never = "never"
    case former = "former"
    case current = "current"

    var displayName: String {
        switch self {
        case .never: return "Never"
        case .former: return "Former smoker"
        case .current: return "Current smoker"
        }
    }
}

nonisolated enum AlcoholFrequency: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case occasional = "occasional"
    case weekly = "weekly"
    case daily = "daily"

    var displayName: String {
        switch self {
        case .none: return "I don't drink"
        case .occasional: return "Occasionally"
        case .weekly: return "A few times a week"
        case .daily: return "Daily"
        }
    }
}

nonisolated enum CoachPersonality: String, Codable, CaseIterable, Sendable, Identifiable {
    case dataNerd = "data_nerd"
    case guardian = "guardian"
    case friend = "friend"
    case commander = "commander"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dataNerd: return "Data Nerd"
        case .guardian: return "Guardian"
        case .friend: return "Friend"
        case .commander: return "Commander"
        }
    }

    var subtitle: String {
        switch self {
        case .dataNerd: return "Numbers-first, scientific tone"
        case .guardian: return "Protective, recovery-oriented"
        case .friend: return "Warm, casual, encouraging"
        case .commander: return "Direct, intense, push-you-harder"
        }
    }

    var icon: String {
        switch self {
        case .dataNerd: return "chart.bar.fill"
        case .guardian: return "shield.lefthalf.filled"
        case .friend: return "person.2.fill"
        case .commander: return "flag.fill"
        }
    }
}

// MARK: - UserProfile

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    var name: String
    var calorieGoal: Int
    var proteinGoal: Double
    var carbsGoal: Double
    var fatGoal: Double
    var hasCompletedOnboarding: Bool

    var gender: Gender?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var targetWeightKg: Double?
    var activityLevel: ActivityLevel?
    var calorieBias: CalorieBias?

    // Additional fields (V1)
    var email: String = ""
    var useLocationForRestaurants: Bool = false
    var dailyRemindersEnabled: Bool = false
    var reminderFrequency: ReminderFrequency = .twice
    var automaticTimeZone: Bool = true
    var dictationLanguage: DictationLanguage = .auto

    // Apple Health toggles
    var healthEnabled: Bool = false
    var healthSendCalories: Bool = true
    var healthSendMacros: Bool = true
    var healthReadBurnedCalories: Bool = true
    var healthReadRestingEnergy: Bool = true
    var healthReadSteps: Bool = true
    var healthReadWorkouts: Bool = true

    // Micronutrient goals
    var trackSugar: Bool = false
    var trackFiber: Bool = false
    var trackSodium: Bool = false
    var sugarGoal: Double? = nil
    var fiberGoal: Double? = nil
    var sodiumGoal: Double? = nil

    // Dietary
    var dietaryPreferences: [DietaryPreference] = []
    var dietaryNotes: String = ""
    var weightGoalType: WeightGoalType = .maintain
    var targetDate: Date? = nil

    // V2 fields
    var allergies: [String] = []
    var hydrationGoalML: Double = 2500
    var caffeineLimitMg: Double = 400
    var cycleTrackingEnabled: Bool = false
    var weightUnit: WeightUnit = .kilograms
    var sleepTargetWakeTime: Date? = nil
    var sleepTargetHours: Int = 8
    var strengthExperience: StrengthExperience = .beginner
    var smokingStatus: SmokingStatus? = nil
    var alcoholFrequency: AlcoholFrequency? = nil
    var supplements: [String] = []
    var coachPersonality: CoachPersonality = .friend

    init(
        name: String = "",
        calorieGoal: Int = 2000,
        proteinGoal: Double = 150,
        carbsGoal: Double = 250,
        fatGoal: Double = 65,
        hasCompletedOnboarding: Bool = false,
        gender: Gender? = nil,
        age: Int? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        targetWeightKg: Double? = nil,
        activityLevel: ActivityLevel? = nil,
        calorieBias: CalorieBias? = nil
    ) {
        self.name = name
        self.calorieGoal = calorieGoal
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatGoal = fatGoal
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.gender = gender
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.targetWeightKg = targetWeightKg
        self.activityLevel = activityLevel
        self.calorieBias = calorieBias
    }

    static let `default` = UserProfile()

    /// TDEE (Total Daily Energy Expenditure) estimate using Mifflin-St Jeor
    var estimatedTDEE: Int? {
        guard let weight = weightKg, let height = heightCm, let age = age, let gender = gender, let activity = activityLevel else {
            return nil
        }
        let bmr: Double
        switch gender {
        case .male:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        case .female:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
        case .other, .preferNotToSay:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 78
        }
        return Int(bmr * activity.multiplier)
    }
}
