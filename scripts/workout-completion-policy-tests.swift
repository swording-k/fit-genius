import Foundation

@main
struct WorkoutCompletionPolicyTests {
    static func main() {
        precondition(WorkoutCompletionPolicy.shouldSaveHealthWorkout(wasDayComplete: false, isDayComplete: true))
        precondition(!WorkoutCompletionPolicy.shouldSaveHealthWorkout(wasDayComplete: true, isDayComplete: true))
        precondition(!WorkoutCompletionPolicy.shouldSaveHealthWorkout(wasDayComplete: true, isDayComplete: false))
        print("Workout completion policy tests passed")
    }
}
