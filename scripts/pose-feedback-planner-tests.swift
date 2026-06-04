import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct PoseFeedbackPlannerTests {
    static func main() {
        let squatSequence = PoseSequence.exerciseFixture(.squat, quality: .risky)
        let squatIssue = FormIssue(
            code: "squat_knee_cave",
            title: "Knee cave",
            detail: "Keep knees tracking over toes",
            severity: 3
        )
        let squatPlan = PoseFeedbackPlanner().makePlan(
            exercise: .squat,
            sequence: squatSequence,
            issues: [squatIssue]
        )

        require(squatPlan.frame.timestamp == 0.8, "squat feedback should select the bottom position")
        require(squatPlan.highlightedJoints.contains(.leftKnee), "knee-cave feedback should highlight the left knee")
        require(squatPlan.highlightedJoints.contains(.rightKnee), "knee-cave feedback should highlight the right knee")
        require(!squatPlan.segments.isEmpty, "feedback should include skeleton segments")

        let benchSequence = PoseSequence.exerciseFixture(.benchPress, quality: .risky)
        let benchIssue = FormIssue(
            code: "bench_elbow_flare",
            title: "Elbow flare",
            detail: "Control the elbows",
            severity: 2
        )
        let benchPlan = PoseFeedbackPlanner().makePlan(
            exercise: .benchPress,
            sequence: benchSequence,
            issues: [benchIssue]
        )

        require(benchPlan.highlightedJoints.contains(.leftElbow), "bench feedback should highlight the left elbow")
        require(benchPlan.highlightedJoints.contains(.rightElbow), "bench feedback should highlight the right elbow")

        print("pose-feedback-planner-tests: PASS")
    }
}
