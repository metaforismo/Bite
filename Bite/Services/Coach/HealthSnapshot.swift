import Foundation

/// HealthKit snapshot bundled into every chat request so Worker tools can reason about
/// today's metrics without round-tripping back to the device.
nonisolated struct HealthSnapshot: Codable, Sendable, Equatable {
    var hrv: Double?               // SDNN ms, 7-day average
    var rhr: Double?               // bpm, latest
    var sleepHours: Double?        // last night's total
    var steps: Int?                // today's steps
    var activeEnergyKcal: Double?  // today's active energy
    var weightKg: Double?
    var heightCm: Double?
    var capturedAt: Date

    static func empty() -> HealthSnapshot {
        HealthSnapshot(capturedAt: Date())
    }
}

@MainActor
extension HealthKitService {
    func snapshot() async -> HealthSnapshot {
        async let hrv = fetchAverageHRV()
        async let rhr = fetchRestingHeartRate()
        async let sleep = fetchLastNightSleepHours()
        async let steps = fetchTodaySteps()
        async let active = fetchTodayActiveEnergy()
        async let weight = fetchLatestWeight()
        async let height = fetchLatestHeight()
        let snapshot = await HealthSnapshot(
            hrv: hrv,
            rhr: rhr,
            sleepHours: sleep,
            steps: steps,
            activeEnergyKcal: active,
            weightKg: weight,
            heightCm: height,
            capturedAt: Date()
        )
        return snapshot
    }
}
