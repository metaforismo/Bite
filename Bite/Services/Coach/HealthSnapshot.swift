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
    var respiratoryRate: Double?   // breaths/min, last night
    var sleepCoreMinutes: Double?  // last night's core sleep
    var sleepDeepMinutes: Double?  // last night's deep sleep
    var sleepRemMinutes: Double?   // last night's REM sleep
    var hrvBaseline60d: Double?    // mean of daily HRV averages, trailing 60 days
    var rhrBaseline60d: Double?    // mean of daily RHR averages, trailing 60 days
    var capturedAt: Date
    var missing: [String] = []     // field names that came back nil

    static func empty() -> HealthSnapshot {
        var snapshot = HealthSnapshot(capturedAt: Date())
        snapshot.missing = snapshot.nilFieldNames
        return snapshot
    }

    var nilFieldNames: [String] {
        var names: [String] = []
        if hrv == nil { names.append("hrv") }
        if rhr == nil { names.append("rhr") }
        if sleepHours == nil { names.append("sleepHours") }
        if steps == nil { names.append("steps") }
        if activeEnergyKcal == nil { names.append("activeEnergyKcal") }
        if weightKg == nil { names.append("weightKg") }
        if heightCm == nil { names.append("heightCm") }
        if respiratoryRate == nil { names.append("respiratoryRate") }
        if sleepCoreMinutes == nil { names.append("sleepCoreMinutes") }
        if sleepDeepMinutes == nil { names.append("sleepDeepMinutes") }
        if sleepRemMinutes == nil { names.append("sleepRemMinutes") }
        if hrvBaseline60d == nil { names.append("hrvBaseline60d") }
        if rhrBaseline60d == nil { names.append("rhrBaseline60d") }
        return names
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
        async let respiratory = fetchLastNightRespiratoryRate()
        async let stages = fetchLastNightSleepStageMinutes()
        async let hrvBaseline = fetchHRVBaseline60d()
        async let rhrBaseline = fetchRHRBaseline60d()
        let stageMinutes = await stages
        var snapshot = await HealthSnapshot(
            hrv: hrv,
            rhr: rhr,
            sleepHours: sleep,
            steps: steps,
            activeEnergyKcal: active,
            weightKg: weight,
            heightCm: height,
            respiratoryRate: respiratory,
            sleepCoreMinutes: stageMinutes?.core,
            sleepDeepMinutes: stageMinutes?.deep,
            sleepRemMinutes: stageMinutes?.rem,
            hrvBaseline60d: hrvBaseline,
            rhrBaseline60d: rhrBaseline,
            capturedAt: Date()
        )
        snapshot.missing = snapshot.nilFieldNames
        return snapshot
    }
}
