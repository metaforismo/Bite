import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.basalBodyTemperature),
            HKQuantityType(.bodyTemperature),
            HKObjectType.workoutType(),
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.menstrualFlow),
            HKCategoryType(.intermenstrualBleeding),
        ]

        let writeTypes: Set<HKSampleType> = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal)
        ]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return store.authorizationStatus(for: HKQuantityType(.dietaryEnergyConsumed)) == .sharingAuthorized
        } catch {
            return false
        }
    }

    // MARK: - Fetch

    func fetchTodaySteps() async -> Int {
        await fetchTodaySum(for: .stepCount, unit: .count())
    }

    func fetchTodayActiveEnergy() async -> Double {
        Double(await fetchTodaySum(for: .activeEnergyBurned, unit: .kilocalorie()))
    }

    func fetchLatestWeight() async -> Double? {
        await fetchLatestQuantity(for: .bodyMass, unit: .gramUnit(with: .kilo))
    }

    func fetchLatestHeight() async -> Double? {
        await fetchLatestQuantity(for: .height, unit: .meterUnit(with: .centi))
    }

    /// Average HRV (SDNN, ms) over the last 7 days. Returns nil if no samples or unauthorized.
    func fetchAverageHRV() async -> Double? {
        guard isAvailable else { return nil }
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
                let value = stats?.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func fetchRestingHeartRate() async -> Double? {
        guard isAvailable else { return nil }
        return await fetchLatestQuantity(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    /// Last night's total sleep duration in hours.
    func fetchLastNightSleepHours() async -> Double? {
        guard isAvailable else { return nil }
        let type = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .hour, value: -24, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleep = categorySamples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
                let totalSeconds = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            store.execute(query)
        }
    }

    /// Last night's sleep stage totals in minutes (core, deep, REM).
    func fetchLastNightSleepStageMinutes() async -> (core: Double, deep: Double, rem: Double)? {
        guard isAvailable else { return nil }
        let type = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .hour, value: -24, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                func minutes(_ stage: HKCategoryValueSleepAnalysis) -> Double {
                    categorySamples
                        .filter { $0.value == stage.rawValue }
                        .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60
                }
                let core = minutes(.asleepCore)
                let deep = minutes(.asleepDeep)
                let rem = minutes(.asleepREM)
                continuation.resume(returning: core + deep + rem > 0 ? (core, deep, rem) : nil)
            }
            store.execute(query)
        }
    }

    /// Average respiratory rate (breaths/min) over the last night's window.
    func fetchLastNightRespiratoryRate() async -> Double? {
        guard isAvailable else { return nil }
        let type = HKQuantityType(.respiratoryRate)
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .hour, value: -24, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
                let value = stats?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Mean of daily HRV (SDNN, ms) averages over the trailing 60 days.
    func fetchHRVBaseline60d() async -> Double? {
        await fetchDailyAverageBaseline(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
    }

    /// Mean of daily resting heart rate averages over the trailing 60 days.
    func fetchRHRBaseline60d() async -> Double? {
        await fetchDailyAverageBaseline(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    /// Start and end of last night's sleep, taken from the actual sample interval.
    func fetchLastNightSleepInterval() async -> (start: Date, end: Date)? {
        guard isAvailable else { return nil }
        let type = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .hour, value: -24, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleep = categorySamples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
                guard let first = asleep.map(\.startDate).min(),
                      let last = asleep.map(\.endDate).max()
                else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (first, last))
            }
            store.execute(query)
        }
    }

    // MARK: - Reproductive Health

    /// Read-only mirror of menstrual flow samples in the given window. Returns
    /// one entry per sample with the HealthKit-canonical flow level mapped to
    /// our SDCycleEntry int (0 none / 1 light / 2 medium / 3 heavy).
    func fetchMenstrualFlowSamples(start: Date, end: Date) async -> [(date: Date, flowLevel: Int)] {
        guard isAvailable else { return [] }
        let type = HKCategoryType(.menstrualFlow)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let mapped = categorySamples.map { sample -> (Date, Int) in
                    let day = Calendar.current.startOfDay(for: sample.startDate)
                    let level: Int
                    switch sample.value {
                    case HKCategoryValueVaginalBleeding.light.rawValue: level = 1
                    case HKCategoryValueVaginalBleeding.medium.rawValue: level = 2
                    case HKCategoryValueVaginalBleeding.heavy.rawValue: level = 3
                    case HKCategoryValueVaginalBleeding.none.rawValue: level = 0
                    default: level = 0
                    }
                    return (day, level)
                }
                continuation.resume(returning: mapped)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Save Dietary Data

    func saveDietaryData(calories: Int, protein: Double, carbs: Double, fat: Double, date: Date) async {
        guard isAvailable else { return }

        let pairs: [(HKQuantityTypeIdentifier, Double, HKUnit)] = [
            (.dietaryEnergyConsumed, Double(calories), .kilocalorie()),
            (.dietaryProtein, protein, .gram()),
            (.dietaryCarbohydrates, carbs, .gram()),
            (.dietaryFatTotal, fat, .gram())
        ]

        for (identifier, value, unit) in pairs where value > 0 {
            let type = HKQuantityType(identifier)
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)

            do {
                try await store.save(sample)
            } catch {
                // Silently fail for individual saves
            }
        }
    }

    // MARK: - Private Helpers

    private func fetchTodaySum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Int {
        guard isAvailable else { return 0 }

        let type = HKQuantityType(identifier)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
                let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                        continuation.resume(returning: value)
                    }
                }
                store.execute(query)
            }
            return Int(result)
        } catch {
            return 0
        }
    }

    private func fetchDailyAverageBaseline(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int = 60) async -> Double? {
        guard isAvailable else { return nil }
        let type = HKQuantityType(identifier)
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .day, value: -days, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let anchor = cal.startOfDay(for: start)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, _ in
                guard let collection else {
                    continuation.resume(returning: nil)
                    return
                }
                var dailyValues: [Double] = []
                collection.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let value = stats.averageQuantity()?.doubleValue(for: unit) {
                        dailyValues.append(value)
                    }
                }
                let mean = dailyValues.isEmpty ? nil : dailyValues.reduce(0, +) / Double(dailyValues.count)
                continuation.resume(returning: mean)
            }
            store.execute(query)
        }
    }

    private func fetchLatestQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard isAvailable else { return nil }

        let type = HKQuantityType(identifier)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
                let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                        continuation.resume(returning: value)
                    }
                }
                store.execute(query)
            }
        } catch {
            return nil
        }
    }
}
