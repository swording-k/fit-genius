import Foundation
import HealthKit

struct HealthAuthorizationScope {
    var includeAdvancedVitals: Bool
    var includeBodyMetrics: Bool

    static let basic = HealthAuthorizationScope(includeAdvancedVitals: false, includeBodyMetrics: false)
}

enum HealthDataServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: return "health_unavailable".localized
        }
    }
}

final class HealthDataService {
    static let shared = HealthDataService()

    private let store = HKHealthStore()
    private let calendar = Calendar.current

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization(scope: HealthAuthorizationScope) async -> Bool {
        guard isAvailable else { return false }
        let readTypes = readTypes(scope: scope)
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    func fetchDailySummaries(days: Int, scope: HealthAuthorizationScope) async throws -> [HealthDailySummaryDTO] {
        guard isAvailable else { throw HealthDataServiceError.unavailable }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: calendar.startOfDay(for: end)) ?? end
        var summaries: [HealthDailySummaryDTO] = []

        for offset in 0..<max(days, 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            summaries.append(try await fetchDailySummary(for: day, scope: scope))
        }
        return summaries
    }

    private func fetchDailySummary(for date: Date, scope: HealthAuthorizationScope) async throws -> HealthDailySummaryDTO {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()

        async let steps = sum(.stepCount, unit: .count(), start: start, end: end)
        async let energy = sum(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let exercise = sum(.appleExerciseTime, unit: .minute(), start: start, end: end)
        async let stand = sum(.appleStandTime, unit: .hour(), start: start, end: end)
        async let workoutMinutes = workoutDurationMinutes(start: start, end: end)
        async let heartRate = average(.heartRate, unit: .count().unitDivided(by: .minute()), start: start, end: end)
        async let resting = average(.restingHeartRate, unit: .count().unitDivided(by: .minute()), start: start, end: end)
        async let hrv = average(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: start, end: end)
        async let sleep = sleepSummary(start: start, end: end)

        let sleepResult = await sleep

        var dto = HealthDailySummaryDTO(
            date: start,
            steps: await steps,
            activeEnergyKcal: await energy,
            exerciseMinutes: await exercise,
            standHours: await stand,
            workoutMinutes: await workoutMinutes,
            averageHeartRate: await heartRate,
            restingHeartRate: await resting,
            hrvSDNN: await hrv,
            sleepMinutes: sleepResult.total,
            deepSleepMinutes: sleepResult.deep,
            remSleepMinutes: sleepResult.rem,
            coreSleepMinutes: sleepResult.core,
            awakeMinutes: sleepResult.awake
        )

        if scope.includeAdvancedVitals {
            dto.oxygenSaturationPercent = await average(.oxygenSaturation, unit: .percent(), start: start, end: end).map { $0 * 100 }
            dto.respiratoryRate = await average(.respiratoryRate, unit: .count().unitDivided(by: .minute()), start: start, end: end)
            dto.vo2Max = await average(.vo2Max, unit: HKUnit(from: "ml/kg*min"), start: start, end: end)
            if #available(iOS 16.0, *) {
                dto.wristTemperatureCelsius = await average(.appleSleepingWristTemperature, unit: .degreeCelsius(), start: start, end: end)
            }
        }

        if scope.includeBodyMetrics {
            dto.bodyMassKg = await mostRecent(.bodyMass, unit: .gramUnit(with: .kilo), end: end)
            dto.bodyFatPercent = await mostRecent(.bodyFatPercentage, unit: .percent(), end: end).map { $0 * 100 }
            dto.bmi = await mostRecent(.bodyMassIndex, unit: .count(), end: end)
            dto.waistCm = await mostRecent(.waistCircumference, unit: .meterUnit(with: .centi), end: end)
        }

        return dto
    }

    private func readTypes(scope: HealthAuthorizationScope) -> Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            quantity(.stepCount),
            quantity(.activeEnergyBurned),
            quantity(.appleExerciseTime),
            quantity(.appleStandTime),
            quantity(.heartRate),
            quantity(.restingHeartRate),
            quantity(.heartRateVariabilitySDNN)
        ].compactMap { $0 }.reduce(into: Set<HKObjectType>()) { $0.insert($1) }

        if scope.includeAdvancedVitals {
            [
                quantity(.oxygenSaturation),
                quantity(.respiratoryRate),
                quantity(.vo2Max)
            ].compactMap { $0 }.forEach { types.insert($0) }
            if #available(iOS 16.0, *), let wristTemperature = quantity(.appleSleepingWristTemperature) {
                types.insert(wristTemperature)
            }
        }

        if scope.includeBodyMetrics {
            [
                quantity(.bodyMass),
                quantity(.bodyFatPercentage),
                quantity(.bodyMassIndex),
                quantity(.waistCircumference)
            ].compactMap { $0 }.forEach { types.insert($0) }
        }

        return types
    }

    private func quantity(_ identifier: HKQuantityTypeIdentifier) -> HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: identifier)
    }

    private func predicate(start: Date, end: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = quantity(identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate(start: start, end: end), options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func average(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = quantity(identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate(start: start, end: end), options: .discreteAverage) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func mostRecent(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, end: Date) async -> Double? {
        guard let type = quantity(identifier) else { return nil }
        let queryPredicate = HKQuery.predicateForSamples(withStart: nil, end: end, options: [])
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: queryPredicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func workoutDurationMinutes(start: Date, end: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate(start: start, end: end), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let minutes = (samples as? [HKWorkout])?.reduce(0) { $0 + $1.duration / 60 }
                continuation.resume(returning: minutes == 0 ? nil : minutes)
            }
            store.execute(query)
        }
    }

    private func sleepSummary(start: Date, end: Date) async -> (total: Double?, deep: Double?, rem: Double?, core: Double?, awake: Double?) {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (nil, nil, nil, nil, nil)
        }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate(start: start, end: end), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                var total = 0.0
                var deep = 0.0
                var rem = 0.0
                var core = 0.0
                var awake = 0.0
                for sample in (samples as? [HKCategorySample]) ?? [] {
                    let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            deep += minutes
                            total += minutes
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            rem += minutes
                            total += minutes
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            core += minutes
                            total += minutes
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            awake += minutes
                        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            total += minutes
                        default:
                            break
                        }
                    } else if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                        total += minutes
                    }
                }
                continuation.resume(returning: (
                    total > 0 ? total : nil,
                    deep > 0 ? deep : nil,
                    rem > 0 ? rem : nil,
                    core > 0 ? core : nil,
                    awake > 0 ? awake : nil
                ))
            }
            store.execute(query)
        }
    }
}
