import Foundation
import Combine
import HealthKit

@MainActor
final class HealthKitWorkoutService: ObservableObject {
    static let shared = HealthKitWorkoutService()

    @Published private(set) var isAuthorized = false
    private let healthStore = HKHealthStore()

    private init() {}

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            isAuthorized = true
            return true
        } catch {
            isAuthorized = false
            return false
        }
    }

    func saveCompletedStrengthWorkout(day: WorkoutDay, endDate: Date = Date()) async throws {
        guard UserDefaults.standard.bool(forKey: "healthKitWorkoutSyncEnabled"),
              await requestAuthorization() else { return }

        let completedLogs = (day.exercises ?? [])
            .flatMap { $0.logs ?? [] }
            .filter { Calendar.current.isDate($0.date, inSameDayAs: endDate) }
        let firstLogDate = completedLogs.map(\.date).min()
        let startDate = min(firstLogDate ?? endDate.addingTimeInterval(-30 * 60), endDate.addingTimeInterval(-60))
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: syncIdentifier(day: day, date: endDate),
            HKMetadataKeySyncVersion: 1,
            "FitGeniusCompletedExercises": (day.exercises ?? []).filter(\.isCompleted).count
        ]
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: metadata
        )
        try await healthStore.save(workout)
    }

    private func syncIdentifier(day: WorkoutDay, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "fitgenius-strength-\(formatter.string(from: date))-day-\(day.dayNumber)"
    }
}
