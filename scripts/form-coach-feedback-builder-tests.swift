import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct FormCoachFeedbackBuilderTests {
    static func main() {
        let engine = FormRuleEngine()
        let summary = engine.analyze(
            exercise: .benchPress,
            sequence: .exerciseFixture(.benchPress, quality: .risky)
        )
        let feedback = FormCoachFeedbackBuilder().build(
            summary: summary,
            feedbackTimestamp: 0.8,
            classificationConfidence: 0.91,
            usedAutomaticDetection: true
        )

        require(
            feedback.priorityCues.count >= 1,
            "risky bench press should produce at least one prioritized coaching cue"
        )
        let combinedCueText = feedback.priorityCues
            .map { "\($0.evidence)\n\($0.whyItMatters)\n\($0.howToFix)\n\($0.drill)" }
            .joined(separator: "\n")
        require(
            combinedCueText.contains("证据") || combinedCueText.contains("Evidence"),
            "coaching cue should expose evidence from the detected frame or metrics"
        )
        require(
            combinedCueText.contains("为什么") || combinedCueText.contains("Why"),
            "coaching cue should explain why the issue matters"
        )
        require(
            combinedCueText.contains("怎么改") || combinedCueText.contains("Fix"),
            "coaching cue should give an actionable correction"
        )
        require(
            combinedCueText.contains("练习") || combinedCueText.contains("Drill"),
            "coaching cue should include a concrete practice drill"
        )
        require(
            feedback.nextSessionPlan.contains("下一次") || feedback.nextSessionPlan.contains("Next"),
            "feedback should include a next-session plan"
        )
        require(
            feedback.filmingTip.contains("拍摄") || feedback.filmingTip.contains("Record"),
            "feedback should include filming guidance so users know how to improve analysis quality"
        )

        let stableSummary = engine.analyze(
            exercise: .benchPress,
            sequence: .exerciseFixture(.benchPress, quality: .good)
        )
        let stableFeedback = FormCoachFeedbackBuilder().build(
            summary: stableSummary,
            feedbackTimestamp: 0,
            classificationConfidence: 0.95,
            usedAutomaticDetection: false
        )
        require(
            stableFeedback.positiveObservations.count >= 2,
            "stable bench press should still teach what looked good"
        )
        require(
            stableFeedback.priorityCues.isEmpty,
            "stable bench press should not invent problems"
        )

        print("form-coach-feedback-builder-tests: PASS")
    }
}
