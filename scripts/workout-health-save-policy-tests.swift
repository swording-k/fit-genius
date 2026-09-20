import Foundation

@main
struct WorkoutHealthSavePolicyTests {
    static func main() {
        require(
            WorkoutHealthSavePolicy.shouldSaveFallbackWorkout(
                wasDayComplete: false,
                isDayComplete: true,
                hasActiveWatchWorkout: false
            ),
            "a phone-only completed plan should save its fallback Health workout"
        )
        require(
            !WorkoutHealthSavePolicy.shouldSaveFallbackWorkout(
                wasDayComplete: false,
                isDayComplete: true,
                hasActiveWatchWorkout: true
            ),
            "an active Watch workout must not be duplicated by a phone fallback"
        )
        require(
            !WorkoutHealthSavePolicy.shouldSaveFallbackWorkout(
                wasDayComplete: true,
                isDayComplete: true,
                hasActiveWatchWorkout: false
            ),
            "re-saving an already completed plan must not create another workout"
        )
        print("workout-health-save-policy-tests: PASS")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
