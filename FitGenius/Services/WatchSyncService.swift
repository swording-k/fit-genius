import Foundation
import SwiftData
import WatchConnectivity

private struct PhoneWatchExercise: Codable {
    let id: String
    let name: String
    let sets: Int
    let reps: String
    let weight: Double
    let isCompleted: Bool
}

private struct PhoneWatchWorkoutContext: Codable {
    let title: String
    let focus: String
    let isRestDay: Bool
    let exercises: [PhoneWatchExercise]
}

@MainActor
final class WatchSyncService: NSObject {
    static let shared = WatchSyncService()

    private weak var modelContext: ModelContext?

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func syncToday(context: ModelContext) {
        modelContext = context
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first,
              let plan = profile.workoutPlan,
              let day = plan.getTodayWorkout() else {
            clear()
            return
        }

        let exercises = (day.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }.enumerated().map { index, exercise in
            PhoneWatchExercise(
                id: "\(day.dayNumber)-\(index)-\(exercise.name)",
                name: exercise.name,
                sets: exercise.sets,
                reps: exercise.reps,
                weight: exercise.weight,
                isCompleted: exercise.isCompleted
            )
        }
        let payload = PhoneWatchWorkoutContext(
            title: plan.name,
            focus: day.focus.rawValue,
            isRestDay: day.isRestDay,
            exercises: exercises
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? WCSession.default.updateApplicationContext(["workout": data])
    }

    func clear() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([:])
    }

    private func completeExercise(id: String) {
        guard let context = modelContext,
              let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first,
              let plan = profile.workoutPlan,
              let day = plan.getTodayWorkout() else { return }
        let sorted = (day.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        guard let exercise = sorted.enumerated().first(where: {
            "\(day.dayNumber)-\($0.offset)-\($0.element.name)" == id
        })?.element, !exercise.isCompleted else { return }
        exercise.toggleCompletion(context: context)
        try? context.save()
        WidgetDataManager.updateWorkoutData(modelContext: context)
        syncToday(context: context)
    }
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            if let context = self.modelContext { self.syncToday(context: context) }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo)
    }

    nonisolated private func receive(_ message: [String: Any]) {
        guard message["action"] as? String == "completeExercise",
              let id = message["exerciseId"] as? String else { return }
        Task { @MainActor in self.completeExercise(id: id) }
    }
}
