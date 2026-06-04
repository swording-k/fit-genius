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

        print("form-coaching-quality-tests: PASS")
    }
}
