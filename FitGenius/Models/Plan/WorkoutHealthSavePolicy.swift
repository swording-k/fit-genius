import Foundation

/// Decides whether the iPhone should create its limited post-hoc workout.
/// A live Apple Watch workout is the authoritative HealthKit record.
enum WorkoutHealthSavePolicy {
    static func shouldSaveFallbackWorkout(
        wasDayComplete: Bool,
        isDayComplete: Bool,
        hasActiveWatchWorkout: Bool
    ) -> Bool {
        !wasDayComplete && isDayComplete && !hasActiveWatchWorkout
    }
}
