import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct FormCoachingQualityTests {
    static func main() {
        let engine = FormRuleEngine()

        for exercise in FormExerciseType.allCases {
            let good = engine.analyze(
                exercise: exercise,
                sequence: .exerciseFixture(exercise, quality: .good)
            )
            let risky = engine.analyze(
                exercise: exercise,
                sequence: .exerciseFixture(exercise, quality: .risky)
            )
            print("\(exercise.rawValue): good=\(good.score) issues=\(good.issues.map { $0.code }); risky=\(risky.score) issues=\(risky.issues.map { $0.code })")
            require(
                good.score > risky.score,
                "\(exercise.rawValue): good form must score above risky form"
            )
            require(
                risky.issues.count > good.issues.count,
                "\(exercise.rawValue): risky form must trigger more issues"
            )
        }

        let overheadGood = engine.analyze(
            exercise: .overheadPress,
            sequence: .exerciseFixture(.overheadPress, quality: .good)
        )
        let overheadRisky = engine.analyze(
            exercise: .overheadPress,
            sequence: .exerciseFixture(.overheadPress, quality: .risky)
        )
        require(overheadGood.score > overheadRisky.score, "overhead press good form must score above risky form")

        let classifier = FormExerciseClassifier()
        for exercise in FormExerciseType.allCases {
            let result = classifier.classify(.exerciseFixture(exercise, quality: .good))
            require(
                result.exercise == exercise,
                "\(exercise.rawValue): classifier should identify the fixture"
            )
            require(
                result.confidence >= 0.55,
                "\(exercise.rawValue): classifier should expose usable confidence"
            )
        }
        require(
            classifier.classify(.exerciseFixture(.overheadPress, quality: .good)).exercise == .overheadPress,
            "classifier should identify a standing overhead press"
        )
        let unsupported = PoseSequence(frames: [
            PoseFrame(timestamp: 0, joints: [
                .leftShoulder: JointPoint(x: 0.43, y: 0.82, confidence: 0.95),
                .rightShoulder: JointPoint(x: 0.57, y: 0.82, confidence: 0.95),
                .leftHip: JointPoint(x: 0.44, y: 0.56, confidence: 0.95),
                .rightHip: JointPoint(x: 0.56, y: 0.56, confidence: 0.95),
                .leftKnee: JointPoint(x: 0.44, y: 0.36, confidence: 0.95),
                .rightKnee: JointPoint(x: 0.56, y: 0.36, confidence: 0.95),
                .leftAnkle: JointPoint(x: 0.42, y: 0.18, confidence: 0.95),
                .rightAnkle: JointPoint(x: 0.58, y: 0.18, confidence: 0.95)
            ])
        ])
        require(!classifier.classify(unsupported).isReliable, "unsupported static motion must not receive a confident exercise label")

        print("form-coaching-quality-tests: PASS")
    }
}
