import Foundation
import HealthKit
import Combine

/// Writes only the user's confirmed FitGenius daily totals. Raw meal photos and
/// individual meal text remain inside FitGenius and are never written to HealthKit.
@MainActor
final class HealthKitNutritionService: ObservableObject {
    static let shared = HealthKitNutritionService()

    @Published private(set) var isAuthorized = false

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    private init() {}

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let types = Set(quantityTypes.values)
        do {
            try await healthStore.requestAuthorization(toShare: types, read: [])
            isAuthorized = true
            return true
        } catch {
            return false
        }
    }

    func sync(day: MealDay) async {
        guard UserDefaults.standard.bool(forKey: "healthKitNutritionSyncEnabled"),
              await requestAuthorization() else {
            return
        }

        do {
            try await removeExistingSamples(for: day.date)
            guard let summary = day.summary else { return }

            let descriptors = HealthNutritionSyncPolicy.samples(
                date: day.date,
                calories: summary.totalCalories,
                protein: summary.protein,
                carbs: summary.carbs,
                fat: summary.fat
            )
            let samples = descriptors.compactMap { makeQuantitySample($0, on: day.date) }
            if !samples.isEmpty {
                try await healthStore.save(samples)
            }
        } catch {
            // A HealthKit sync failure must never block a local meal edit.
            #if DEBUG
            print("[HealthKit] Nutrition sync failed: \(error.localizedDescription)")
            #endif
        }
    }

    private var quantityTypes: [HealthNutritionSyncPolicy.Metric: HKQuantityType] {
        [
            .energy: HKQuantityType(.dietaryEnergyConsumed),
            .protein: HKQuantityType(.dietaryProtein),
            .carbs: HKQuantityType(.dietaryCarbohydrates),
            .fat: HKQuantityType(.dietaryFatTotal)
        ]
    }

    private func makeQuantitySample(_ descriptor: HealthNutritionSyncPolicy.Sample, on day: Date) -> HKQuantitySample? {
        guard let type = quantityTypes[descriptor.metric] else { return nil }
        let unit: HKUnit = descriptor.metric == .energy ? .kilocalorie() : .gram()
        let date = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: day)) ?? day
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: descriptor.identifier,
            HKMetadataKeySyncVersion: 1
        ]
        return HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: descriptor.value), start: date, end: date, metadata: metadata)
    }

    private func removeExistingSamples(for date: Date) async throws {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        for metric in HealthNutritionSyncPolicy.Metric.allCases {
            guard let type = quantityTypes[metric] else { continue }
            let identifier = HealthNutritionSyncPolicy.samples(date: date, calories: 0, protein: 0, carbs: 0, fat: 0)
                .first(where: { $0.metric == metric })?.identifier
            guard let identifier else { continue }
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate),
                HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [identifier])
            ])

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                healthStore.deleteObjects(of: type, predicate: predicate) { success, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CocoaError(.fileWriteUnknown))
                    }
                }
            }
        }
    }
}
