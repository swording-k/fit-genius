import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var workoutContext: WatchWorkoutContext?
    @Published private(set) var completedSets: [String: Int] = [:]

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        decode(WCSession.default.receivedApplicationContext)
    }

    func completeSet(_ exercise: WatchExercise) {
        let nextCount = min((completedSets[exercise.id] ?? 0) + 1, exercise.sets)
        completedSets[exercise.id] = nextCount
        guard nextCount >= exercise.sets else { return }
        complete(exercise)
    }

    func completedSetCount(for exercise: WatchExercise) -> Int {
        completedSets[exercise.id] ?? 0
    }

    private func complete(_ exercise: WatchExercise) {
        guard var context = workoutContext,
              let index = context.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        context.exercises[index].isCompleted = true
        workoutContext = context
        let message: [String: Any] = ["action": "completeExercise", "exerciseId": exercise.id]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    private func decode(_ dictionary: [String: Any]) {
        guard let data = dictionary["workout"] as? Data,
              let context = try? JSONDecoder().decode(WatchWorkoutContext.self, from: data) else {
            workoutContext = nil
            completedSets = [:]
            return
        }
        workoutContext = context
        let activeIds = Set(context.exercises.filter { !$0.isCompleted }.map(\.id))
        completedSets = completedSets.filter { activeIds.contains($0.key) }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.decode(applicationContext) }
    }
}
