import Foundation

@main
struct PlanEditValidationTests {
    static func main() {
        let plan = PlanEditSnapshot(days: [
            .init(dayNumber: 1, isRestDay: false, exerciseNames: ["Barbell Bench Press"]),
            .init(dayNumber: 2, isRestDay: true, exerciseNames: [])
        ])

        require(
            PlanEditValidationPolicy.validate(
                .init(kind: .update, dayNumber: 1, targetName: "Barbell Bench Press", replacementName: "Dumbbell Bench Press", sets: 4, reps: "8-12", weight: 20),
                against: plan
            ).isValid,
            "a unique in-range update should be valid"
        )

        require(
            !PlanEditValidationPolicy.validate(
                .init(kind: .update, dayNumber: 1, targetName: "Barbell Bench Press", replacementName: "Dumbbell Bench Press", sets: 0, reps: "8-12", weight: 20),
                against: plan
            ).isValid,
            "sets outside 1...20 must be rejected"
        )

        require(
            !PlanEditValidationPolicy.validate(
                .init(kind: .add, dayNumber: 2, targetName: nil, replacementName: "Squat", sets: 3, reps: "8", weight: 0),
                against: plan
            ).isValid,
            "a rest day must not accept an exercise"
        )

        require(
            !PlanEditValidationPolicy.validate(
                .init(kind: .remove, dayNumber: 3, targetName: "Row", replacementName: nil, sets: nil, reps: nil, weight: nil),
                against: plan
            ).isValid,
            "an unknown day must be rejected"
        )

        let duplicatePlan = PlanEditSnapshot(days: [
            .init(dayNumber: 1, isRestDay: false, exerciseNames: ["Row", "Row"])
        ])
        require(
            !PlanEditValidationPolicy.validate(
                .init(kind: .remove, dayNumber: 1, targetName: "Row", replacementName: nil, sets: nil, reps: nil, weight: nil),
                against: duplicatePlan
            ).isValid,
            "a non-unique target must be rejected"
        )

        require(
            PlanEditValidationPolicy.validateReplacement(plan).isValid,
            "a plan with one training day and one empty rest day should be valid"
        )

        require(
            !PlanEditValidationPolicy.validateReplacement(
                .init(days: [
                    .init(dayNumber: 1, isRestDay: true, exerciseNames: ["Squat"])
                ])
            ).isValid,
            "a replacement must reject exercises on rest days"
        )

        require(
            !PlanEditValidationPolicy.validateReplacement(
                .init(days: [
                    .init(dayNumber: 1, isRestDay: false, exerciseNames: ["Squat"]),
                    .init(dayNumber: 3, isRestDay: false, exerciseNames: ["Row"])
                ])
            ).isValid,
            "replacement day numbers must be continuous"
        )

        print("plan-edit-validation-tests: PASS")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
