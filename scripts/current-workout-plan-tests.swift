import Foundation

@main
struct CurrentWorkoutPlanPolicyTests {
    static func main() {
        let old = Date(timeIntervalSince1970: 100)
        let recent = Date(timeIntervalSince1970: 200)

        require(
            CurrentWorkoutPlanPolicy.selectID(from: [
                .init(id: "standalone", creationDate: recent, isLinkedToProfile: false),
                .init(id: "linked", creationDate: old, isLinkedToProfile: true)
            ]) == "linked",
            "a profile-linked plan must win over a newer standalone draft"
        )

        require(
            CurrentWorkoutPlanPolicy.selectID(from: [
                .init(id: "old", creationDate: old, isLinkedToProfile: false),
                .init(id: "recent", creationDate: recent, isLinkedToProfile: false)
            ]) == "recent",
            "the newest standalone plan should be selected when no profile is linked"
        )

        require(
            CurrentWorkoutPlanPolicy.selectID(from: []) as String? == nil,
            "an empty store must not invent a plan candidate"
        )

        print("current-workout-plan-tests: PASS")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
