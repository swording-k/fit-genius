import Foundation

enum WorkoutCompletionPolicy {
    static func shouldSaveHealthWorkout(wasDayComplete: Bool, isDayComplete: Bool) -> Bool {
        !wasDayComplete && isDayComplete
    }
}
