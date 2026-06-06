import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct FormAnalysisQualityGateTests {
    static func main() {
        let validSquat = PoseSequence.exerciseFixture(.squat, quality: .good)
        let validReport = FormAnalysisQualityGate.report(for: validSquat)
        expect(validReport.isUsable, "Good squat fixture should pass the quality gate")

        let tinyOutro = PoseFrame(timestamp: 2.0, joints: [
            .leftShoulder: JointPoint(x: 0.50, y: 0.50, confidence: 0.95),
            .rightShoulder: JointPoint(x: 0.52, y: 0.50, confidence: 0.95),
            .leftElbow: JointPoint(x: 0.50, y: 0.51, confidence: 0.95),
            .rightElbow: JointPoint(x: 0.52, y: 0.51, confidence: 0.95),
            .leftWrist: JointPoint(x: 0.50, y: 0.52, confidence: 0.95),
            .rightWrist: JointPoint(x: 0.52, y: 0.52, confidence: 0.95)
        ])
        let tinyReport = FormAnalysisQualityGate.report(for: PoseSequence(frames: [tinyOutro, tinyOutro, tinyOutro]))
        expect(!tinyReport.isUsable, "Tiny creator/avatar-like frames should not pass the quality gate")

        let staticFrames = Array(repeating: validSquat.frames[0], count: 3)
        let staticReport = FormAnalysisQualityGate.report(for: PoseSequence(frames: staticFrames))
        expect(!staticReport.isUsable, "Static or non-lifting clips should not pass the quality gate")

        print("form-analysis-quality-gate-tests: PASS")
    }
}
