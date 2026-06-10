import Foundation

enum HealthDataProviderKind: String, Codable, CaseIterable, Identifiable {
    case appleHealth
    case googleHealth
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleHealth: return "Apple Health"
        case .googleHealth: return "Google Health"
        case .manual: return "Manual"
        }
    }
}

struct NormalizedHealthSnapshot: Codable, Equatable, Sendable {
    var provider: HealthDataProviderKind
    var capturedAt: Date
    var hrv: Double?
    var restingHeartRate: Double?
    var sleepHours: Double?
    var steps: Int?
    var activeEnergyKcal: Double?
    var weightKg: Double?
    var heightCm: Double?

    init(
        provider: HealthDataProviderKind,
        capturedAt: Date = Date(),
        hrv: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil,
        steps: Int? = nil,
        activeEnergyKcal: Double? = nil,
        weightKg: Double? = nil,
        heightCm: Double? = nil
    ) {
        self.provider = provider
        self.capturedAt = capturedAt
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.weightKg = weightKg
        self.heightCm = heightCm
    }
}

protocol HealthDataProviding {
    var kind: HealthDataProviderKind { get }
    func snapshot() async -> NormalizedHealthSnapshot
}

@MainActor
struct AppleHealthDataProvider: HealthDataProviding {
    var kind: HealthDataProviderKind { .appleHealth }
    private let healthKit = HealthKitService.shared

    func snapshot() async -> NormalizedHealthSnapshot {
        async let hrv = healthKit.fetchAverageHRV()
        async let rhr = healthKit.fetchRestingHeartRate()
        async let sleep = healthKit.fetchLastNightSleepHours()
        async let steps = healthKit.fetchTodaySteps()
        async let active = healthKit.fetchTodayActiveEnergy()
        async let weight = healthKit.fetchLatestWeight()
        async let height = healthKit.fetchLatestHeight()
        return await NormalizedHealthSnapshot(
            provider: .appleHealth,
            hrv: hrv,
            restingHeartRate: rhr,
            sleepHours: sleep,
            steps: steps,
            activeEnergyKcal: active,
            weightKg: weight,
            heightCm: height
        )
    }
}

struct GoogleHealthDataProvider: HealthDataProviding {
    var kind: HealthDataProviderKind { .googleHealth }

    func snapshot() async -> NormalizedHealthSnapshot {
        // OAuth and cloud sync are intentionally deferred. This provider is
        // the stable extension point for Google Health / Fitbit Air data.
        NormalizedHealthSnapshot(provider: .googleHealth)
    }
}
