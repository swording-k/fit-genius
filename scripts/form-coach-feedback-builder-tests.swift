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

        let json = """
        {
          "coach_note": "Keep the setup stable before pressing.",
          "selected_frame_indexes": [0, 2],
          "annotations": [
            {
              "image_index": 0,
              "label": "Stack wrist over elbow",
              "type": "highlight",
              "joints": ["leftWrist", "leftElbow"],
              "severity": 2
            }
          ],
          "cues": [
            {
              "title": "Set the press path",
              "evidence": "The wrist path moves around more than expected.",
              "why_it_matters": "A drifting wrist makes force transfer worse.",
              "how_to_fix": "Keep knuckles up and forearms close to vertical.",
              "drill": "Use paused reps for the next two warm-up sets."
            }
          ]
        }
        """
        let decoded = try! JSONDecoder().decode(
            FormCoachEnrichmentResult.self,
            from: Data(json.utf8)
        )
        require(decoded.coachNote == "Keep the setup stable before pressing.", "coach_note should decode")
        require(decoded.selectedFrameIndexes == [0, 2], "selected_frame_indexes should decode")
        require(decoded.annotations.first?.imageIndex == 0, "image_index should decode")
        require(decoded.annotations.first?.resolvedJoints == [.leftWrist, .leftElbow], "annotation joints should resolve")
        require(decoded.cues.first?.whyItMatters.contains("drifting wrist") == true, "why_it_matters should decode into FormCoachCue")
        require(decoded.cues.first?.howToFix.contains("knuckles") == true, "how_to_fix should decode into FormCoachCue")

        let enrichedFeedback = FormCoachFeedbackBuilder().build(
            summary: stableSummary,
            feedbackTimestamp: 0,
            classificationConfidence: 0.95,
            usedAutomaticDetection: false,
            enrichmentCues: decoded.cues
        )
        require(
            enrichedFeedback.priorityCues.first?.title == "Set the press path",
            "AI enrichment cues should override local stable no-issue cues when provided"
        )

        print("form-coach-feedback-builder-tests: PASS")
    }
}
