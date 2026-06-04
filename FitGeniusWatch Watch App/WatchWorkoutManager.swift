import Foundation
import Combine
import HealthKit

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isActive = false
    @Published var heartRate: Double = 0
    @Published var restRemaining = 0

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var restTask: Task<Void, Never>?

    func start() {
        Task {
            guard HKHealthStore.isHealthDataAvailable(),
                  let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
            do {
                try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [heartRate])
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = .traditionalStrengthTraining
                configuration.locationType = .indoor
                let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
                session.delegate = self
                builder.delegate = self
                self.session = session
                self.builder = builder
                let now = Date()
                session.startActivity(with: now)
                try await builder.beginCollection(at: now)
                isActive = true
            } catch {
                isActive = false
            }
        }
    }

    func end() {
        session?.end()
        isActive = false
        cancelRest()
    }

    func startRest(seconds: Int) {
        restTask?.cancel()
        restRemaining = seconds
        restTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.restRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.restRemaining -= 1
            }
        }
    }

    func cancelRest() {
        restTask?.cancel()
        restTask = nil
        restRemaining = 0
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended else { return }
        Task { @MainActor in
            try? await builder?.endCollection(at: date)
            _ = try? await builder?.finishWorkout()
            isActive = false
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in self.isActive = false }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(type),
              let statistics = workoutBuilder.statistics(for: type),
              let value = statistics.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) else { return }
        Task { @MainActor in self.heartRate = value }
    }
}
