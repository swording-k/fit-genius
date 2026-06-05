import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func tinyOutroFrame(timestamp: Double) -> PoseFrame {
    let centerX = 0.50
    let centerY = 0.50
    let spread = 0.025
    return PoseFrame(timestamp: timestamp, joints: [
        .leftShoulder: JointPoint(x: centerX - spread, y: centerY + spread, confidence: 0.95),
        .rightShoulder: JointPoint(x: centerX + spread, y: centerY + spread, confidence: 0.95),
        .leftElbow: JointPoint(x: centerX - spread, y: centerY, confidence: 0.95),
        .rightElbow: JointPoint(x: centerX + spread, y: centerY, confidence: 0.95),
        .leftWrist: JointPoint(x: centerX - spread, y: centerY - spread, confidence: 0.95),
        .rightWrist: JointPoint(x: centerX + spread, y: centerY - spread, confidence: 0.95),
        .leftHip: JointPoint(x: centerX - spread, y: centerY - spread * 2, confidence: 0.95),
        .rightHip: JointPoint(x: centerX + spread, y: centerY - spread * 2, confidence: 0.95)
    ])
}

@main
struct PoseFrameQualityPolicyTests {
    static func main() {
        let normalBench = PoseSequence.exerciseFixture(.benchPress, quality: .good)
        let tinyOutro = tinyOutroFrame(timestamp: 31.9)

        require(
            !PoseFrameQualityPolicy.isUsableForFormAnalysis(tinyOutro),
            "tiny social-media outro avatar should not count as a usable lifting frame"
        )

        let mixedSequence = PoseSequence(frames: normalBench.frames + [tinyOutro])
        let plan = PoseFeedbackPlanner().makePlan(
            exercise: .benchPress,
            sequence: mixedSequence,
            issues: []
        )

        require(
            plan.frame.timestamp != 31.9,
            "feedback planner should not select the filtered outro frame as key feedback"
        )
        require(
            plan.frame.timestamp <= 1.6,
            "feedback key frame should come from the actual bench-press movement"
        )

        print("pose-frame-quality-policy-tests: PASS")
    }
}
