import Foundation

struct FormCoachCue: Codable, Hashable {
    let title: String
    let evidence: String
    let whyItMatters: String
    let howToFix: String
    let drill: String

    private enum CodingKeys: String, CodingKey {
        case title
        case evidence
        case whyItMatters = "why_it_matters"
        case howToFix = "how_to_fix"
        case drill
    }
}

struct FormCoachFeedback: Hashable {
    let headline: String
    let keyFrameExplanation: String
    let positiveObservations: [String]
    let priorityCues: [FormCoachCue]
    let nextSessionPlan: String
    let filmingTip: String
    let limitationNote: String

    var assistantText: String {
        var sections: [String] = [
            headline,
            "",
            section("form_coach_key_frame_title", fallback: "Key frame", body: keyFrameExplanation)
        ]

        if !positiveObservations.isEmpty {
            sections.append(section(
                "form_coach_positive_title",
                fallback: "What looks good",
                body: positiveObservations.map { "• \($0)" }.joined(separator: "\n")
            ))
        }

        if priorityCues.isEmpty {
            sections.append(section(
                "form_coach_priority_title",
                fallback: "Priority fixes",
                body: localize(
                    "form_coach_no_major_issue_detail",
                    fallback: "No major issue was detected in the visible frames. Keep using the same technique checklist and compare future videos from the same angle."
                )
            ))
        } else {
            let cueText = priorityCues.enumerated().map { index, cue in
                """
                \(index + 1). \(cue.title)
                \(cue.evidence)
                \(cue.whyItMatters)
                \(cue.howToFix)
                \(cue.drill)
                """
            }.joined(separator: "\n\n")
            sections.append(section("form_coach_priority_title", fallback: "Priority fixes", body: cueText))
        }

        sections.append(section("form_coach_next_session_title", fallback: "Next session", body: nextSessionPlan))
        sections.append(section("form_coach_filming_title", fallback: "Record it better", body: filmingTip))
        sections.append(limitationNote)
        return sections.joined(separator: "\n\n")
    }

    private func section(_ key: String, fallback: String, body: String) -> String {
        "\(FormCoachFeedbackBuilder.localize(key, fallback: fallback))\n\(body)"
    }

    private func localize(_ key: String, fallback: String) -> String {
        FormCoachFeedbackBuilder.localize(key, fallback: fallback)
    }
}

struct FormCoachFeedbackBuilder {
    func build(
        summary: FormAnalysisSummary,
        feedbackTimestamp: Double,
        classificationConfidence: Double,
        usedAutomaticDetection: Bool,
        enrichmentCues: [FormCoachCue] = []
    ) -> FormCoachFeedback {
        let metrics = Dictionary(uniqueKeysWithValues: summary.metrics.map { ($0.key, $0) })
        let localCues = summary.issues.map { cue(for: $0, exercise: summary.exerciseType, metrics: metrics) }
        let priorityCues = enrichmentCues.isEmpty ? localCues : enrichmentCues
        let positives = positiveObservations(for: summary.exerciseType, hasIssues: !summary.issues.isEmpty)
        let headline = headline(
            summary: summary,
            classificationConfidence: classificationConfidence,
            usedAutomaticDetection: usedAutomaticDetection
        )

        return FormCoachFeedback(
            headline: headline,
            keyFrameExplanation: keyFrameExplanation(
                exercise: summary.exerciseType,
                timestamp: feedbackTimestamp
            ),
            positiveObservations: positives,
            priorityCues: Array(priorityCues.prefix(3)),
            nextSessionPlan: nextSessionPlan(for: summary.exerciseType, issues: summary.issues),
            filmingTip: filmingTip(for: summary.exerciseType),
            limitationNote: localize(
                "form_coach_limitation_note",
                fallback: "This is on-device pose analysis from visible joints. It is training feedback, not medical advice."
            )
        )
    }

    private func headline(
        summary: FormAnalysisSummary,
        classificationConfidence: Double,
        usedAutomaticDetection: Bool
    ) -> String {
        let source = usedAutomaticDetection
            ? String(format: localize("form_coach_auto_source_format", fallback: "Auto-detected %@, confidence %d%%."), summary.exerciseType.displayName, Int((classificationConfidence * 100).rounded()))
            : String(format: localize("form_coach_manual_source_format", fallback: "Analyzing manually selected %@."), summary.exerciseType.displayName)
        let status = summary.issues.isEmpty
            ? localize("form_coach_stable_headline", fallback: "No major technique issue was detected in this clip.")
            : localize("form_coach_attention_headline", fallback: "The score is useful, but the priority is learning the correction below.")
        return "\(source)\n\(summary.exerciseType.displayName) \(summary.score) \(localize("form_coach_points", fallback: "points"))：\(status)"
    }

    private func keyFrameExplanation(exercise: FormExerciseType, timestamp: Double) -> String {
        let reason: String
        switch exercise {
        case .squat:
            reason = localize("form_coach_key_frame_squat", fallback: "I selected the bottom-position frame because squat depth and knee tracking are easiest to judge there.")
        case .deadlift:
            reason = localize("form_coach_key_frame_deadlift", fallback: "I selected the hinge frame where torso and hip position are easiest to inspect.")
        case .benchPress:
            reason = localize("form_coach_key_frame_bench", fallback: "I selected the press frame where wrist, elbow, and shoulder alignment are most visible.")
        case .overheadPress:
            reason = localize("form_coach_key_frame_overhead", fallback: "I selected the overhead position because lockout, wrist symmetry, and torso compensation are easiest to judge there.")
        }
        return String(format: localize("form_coach_key_frame_format", fallback: "Video %.1f s. %@"), timestamp, reason)
    }

    private func positiveObservations(for exercise: FormExerciseType, hasIssues: Bool) -> [String] {
        switch exercise {
        case .squat:
            return [
                localize("form_coach_positive_squat_1", fallback: "The app found enough hip, knee, and ankle points to evaluate the squat pattern."),
                hasIssues
                    ? localize("form_coach_positive_squat_2_attention", fallback: "You have a usable movement pattern; fix the priority cue before adding load.")
                    : localize("form_coach_positive_squat_2_stable", fallback: "Depth and knee tracking look controlled in the visible frames.")
            ]
        case .deadlift:
            return [
                localize("form_coach_positive_deadlift_1", fallback: "The app found the main hip-hinge joints needed for deadlift feedback."),
                hasIssues
                    ? localize("form_coach_positive_deadlift_2_attention", fallback: "The setup is readable; the next improvement is tighter bracing and bar path control.")
                    : localize("form_coach_positive_deadlift_2_stable", fallback: "The hinge shape looks controlled in the visible frames.")
            ]
        case .benchPress:
            return [
                localize("form_coach_positive_bench_1", fallback: "The app found shoulders, elbows, and wrists, so it can inspect the pressing line."),
                hasIssues
                    ? localize("form_coach_positive_bench_2_attention", fallback: "Your press is analyzable; focus on the first correction instead of chasing the score.")
                    : localize("form_coach_positive_bench_2_stable", fallback: "The visible press path looks consistent enough to keep practicing from the same angle.")
            ]
        case .overheadPress:
            return [
                localize("form_coach_positive_overhead_1", fallback: "The app found the upper-body joints needed to inspect the overhead path."),
                hasIssues
                    ? localize("form_coach_positive_overhead_2_attention", fallback: "The rep is readable; the next improvement is more controlled lockout and trunk position.")
                    : localize("form_coach_positive_overhead_2_stable", fallback: "The visible lockout and left-right timing look stable.")
            ]
        }
    }

    private func cue(
        for issue: FormIssue,
        exercise: FormExerciseType,
        metrics: [String: FormMetric]
    ) -> FormCoachCue {
        let value = evidenceValue(for: issue.code, metrics: metrics)
        let fallback = defaultCueText(issue: issue, exercise: exercise, value: value)
        return FormCoachCue(
            title: issue.title,
            evidence: prefix("form_coach_evidence_prefix", fallback: "Evidence", text: fallback.evidence),
            whyItMatters: prefix("form_coach_why_prefix", fallback: "Why it matters", text: fallback.why),
            howToFix: prefix("form_coach_fix_prefix", fallback: "Fix", text: fallback.fix),
            drill: prefix("form_coach_drill_prefix", fallback: "Drill", text: fallback.drill)
        )
    }

    private func defaultCueText(
        issue: FormIssue,
        exercise: FormExerciseType,
        value: String
    ) -> (evidence: String, why: String, fix: String, drill: String) {
        switch issue.code {
        case "bench_elbow_flare":
            return (
                String(format: localize("form_coach_evidence_bench_elbow_flare", fallback: "Elbows drift wider than the shoulders in the selected frame%@."), value),
                localize("form_coach_why_bench_elbow_flare", fallback: "Too much flare can move tension toward the front shoulder and make the bar path harder to repeat."),
                localize("form_coach_fix_bench_elbow_flare", fallback: "Before lowering, pull the shoulder blades back and down, then keep elbows roughly 45-70 degrees from the torso."),
                localize("form_coach_drill_bench_elbow_flare", fallback: "Use 2 sets of 5 paused reps with an empty bar or lighter load; pause one second near the bottom and check that forearms stay nearly vertical.")
            )
        case "bench_elbow_angle":
            return (
                String(format: localize("form_coach_evidence_bench_elbow_angle", fallback: "The bottom-position elbow angle is very small%@."), value),
                localize("form_coach_why_bench_elbow_angle", fallback: "A cramped bottom position can reduce pressing stability and make the wrists or shoulders compensate."),
                localize("form_coach_fix_bench_elbow_angle", fallback: "Adjust grip so the wrist stacks over the elbow at the bottom; lower the bar under control to the lower chest."),
                localize("form_coach_drill_bench_elbow_angle", fallback: "Try 3-second eccentric bench for 2 sets of 4-6 reps at 70-80% of the usual working weight.")
            )
        case "bench_press_asymmetry", "overhead_wrist_asymmetry":
            return (
                String(format: localize("form_coach_evidence_asymmetry", fallback: "Left and right wrist heights differ in the key frame%@."), value),
                localize("form_coach_why_asymmetry", fallback: "Asymmetry often means one side is losing position, which can hide strength imbalance or fatigue."),
                localize("form_coach_fix_asymmetry", fallback: "Slow the rep down and think about pushing both hands through the same path at the same time."),
                localize("form_coach_drill_asymmetry", fallback: "Use lighter tempo reps or dumbbell work for 2 sets, stopping each set when one side starts drifting.")
            )
        case "bench_wrist_path":
            return (
                String(format: localize("form_coach_evidence_bench_wrist_path", fallback: "The wrist path moves around more than expected%@."), value),
                localize("form_coach_why_bench_wrist_path", fallback: "An unstable wrist path usually makes the bar harder to control and can reduce force transfer."),
                localize("form_coach_fix_bench_wrist_path", fallback: "Keep knuckles pointed up, wrists stacked over forearms, and move the bar smoothly instead of letting it drift."),
                localize("form_coach_drill_bench_wrist_path", fallback: "Film 2 lighter sets from the same angle and aim for the wrists to trace the same line each rep.")
            )
        case "bench_limited_range":
            return (
                String(format: localize("form_coach_evidence_bench_range", fallback: "The wrist travel range is limited%@."), value),
                localize("form_coach_why_bench_range", fallback: "A short range may be intentional, but if unplanned it reduces training stimulus and makes progress harder to compare."),
                localize("form_coach_fix_bench_range", fallback: "Use a shoulder-comfortable range, touch a consistent point, and lock out without bouncing."),
                localize("form_coach_drill_bench_range", fallback: "Do paused bench with a lighter load and repeat the same touch point for every rep.")
            )
        case "squat_depth_limited":
            return (
                String(format: localize("form_coach_evidence_squat_depth", fallback: "Hip depth stays above the target range%@."), value),
                localize("form_coach_why_squat_depth", fallback: "Consistent depth makes leg training measurable and prevents accidentally shortening hard reps."),
                localize("form_coach_fix_squat_depth", fallback: "Brace first, sit between the hips, and keep knees tracking over the toes as you descend."),
                localize("form_coach_drill_squat_depth", fallback: "Use goblet squat or box squat for 2 sets of 6, pausing briefly at the same depth.")
            )
        case "squat_knee_cave", "deadlift_knee_track":
            return (
                String(format: localize("form_coach_evidence_knee_track", fallback: "The knees drift away from the foot line%@."), value),
                localize("form_coach_why_knee_track", fallback: "Poor knee tracking can make the lift less stable and harder to repeat under fatigue."),
                localize("form_coach_fix_knee_track", fallback: "Think knees follow toes; keep pressure through the mid-foot instead of collapsing inward."),
                localize("form_coach_drill_knee_track", fallback: "Use controlled tempo reps and stop the set when knee position changes.")
            )
        case "squat_torso_lean", "deadlift_back_position", "overhead_torso_lean":
            return (
                String(format: localize("form_coach_evidence_torso", fallback: "Torso position changes beyond the expected range%@."), value),
                localize("form_coach_why_torso", fallback: "Losing torso position usually means the brace or load is not under control."),
                localize("form_coach_fix_torso", fallback: "Brace before the rep, keep ribs down, and reduce load if position changes during the hard part."),
                localize("form_coach_drill_torso", fallback: "Practice 2 lighter sets with a 2-second pause at the hardest position while keeping the torso still.")
            )
        case "overhead_lockout_limited":
            return (
                String(format: localize("form_coach_evidence_overhead_lockout", fallback: "The top elbow extension is below the target range%@."), value),
                localize("form_coach_why_overhead_lockout", fallback: "Limited lockout can turn the press into a partial rep and hide shoulder or triceps fatigue."),
                localize("form_coach_fix_overhead_lockout", fallback: "Finish with biceps near ears, ribs down, and elbows comfortably extended."),
                localize("form_coach_drill_overhead_lockout", fallback: "Use lighter strict presses for 2 sets of 5, pausing one second overhead without leaning back.")
            )
        case "pose_quality_low", "bench_camera_angle_limited":
            return (
                localize("form_coach_evidence_pose_quality", fallback: "Some required joints were missing or too small in the frame."),
                localize("form_coach_why_pose_quality", fallback: "If the camera cannot see the joints, the app may miss the real mistake or choose a weaker key frame."),
                localize("form_coach_fix_pose_quality", fallback: "Keep the full body or relevant limb chain large in frame, with no platform intro or ending screen."),
                localize("form_coach_drill_pose_quality", fallback: "Record one clean side-front test clip before working sets and analyze that clip first.")
            )
        default:
            return (
                issue.detail,
                localize("form_coach_why_default", fallback: "This cue affects repeatability and control."),
                localize("form_coach_fix_default", fallback: "Lower the load slightly and make the next set slower and more deliberate."),
                localize("form_coach_drill_default", fallback: "Practice 2 lighter sets and film again from the same angle.")
            )
        }
    }

    private func nextSessionPlan(for exercise: FormExerciseType, issues: [FormIssue]) -> String {
        if issues.isEmpty {
            return localize("form_coach_next_stable", fallback: "Next time: keep the same load or add a small amount only if every rep still looks the same on video.")
        }
        let firstIssue = issues.first?.title ?? localize("form_coach_priority_title", fallback: "Priority fixes")
        switch exercise {
        case .squat:
            return String(format: localize("form_coach_next_squat", fallback: "Next time: keep the working weight conservative, spend the first 2 sets on %@, then only add load if depth and knee tracking stay consistent."), firstIssue)
        case .deadlift:
            return String(format: localize("form_coach_next_deadlift", fallback: "Next time: use a slightly lighter first work set, fix %@, and stop the set when back or knee position changes."), firstIssue)
        case .benchPress:
            return String(format: localize("form_coach_next_bench", fallback: "Next time: reduce the first work set by 5-10%% if needed, fix %@, and record one side-front set to compare wrist-elbow alignment."), firstIssue)
        case .overheadPress:
            return String(format: localize("form_coach_next_overhead", fallback: "Next time: choose a weight you can lock out cleanly, focus on %@, and pause one second overhead on each rep."), firstIssue)
        }
    }

    private func filmingTip(for exercise: FormExerciseType) -> String {
        switch exercise {
        case .squat:
            return localize("form_coach_filming_squat", fallback: "Record from 45 degrees front-side, showing feet, knees, hips, and shoulders for the full rep.")
        case .deadlift:
            return localize("form_coach_filming_deadlift", fallback: "Record from 45 degrees front-side with the bar, hips, knees, and shoulders visible from setup to lockout.")
        case .benchPress:
            return localize("form_coach_filming_bench", fallback: "Record from a side-front angle above bench height so shoulders, elbows, wrists, and bar path stay visible. Trim social-media endings before uploading.")
        case .overheadPress:
            return localize("form_coach_filming_overhead", fallback: "Record from front-side with the whole body visible, especially wrists overhead and ribs/hips during lockout.")
        }
    }

    private func evidenceValue(for issueCode: String, metrics: [String: FormMetric]) -> String {
        let metricKey: String?
        switch issueCode {
        case "bench_elbow_flare":
            metricKey = "bench_elbow_flare"
        case "bench_elbow_angle":
            metricKey = "bench_elbow_angle"
        case "bench_press_asymmetry":
            metricKey = "bench_asymmetry"
        case "bench_wrist_path":
            metricKey = "bench_wrist_path"
        case "bench_limited_range":
            metricKey = "bench_range_of_motion"
        case "squat_depth_limited":
            metricKey = "squat_depth_delta"
        case "squat_knee_cave", "deadlift_knee_track":
            metricKey = issueCode == "deadlift_knee_track" ? "deadlift_knee_track" : "squat_knee_cave"
        case "deadlift_back_position":
            metricKey = "deadlift_hip_angle"
        case "overhead_lockout_limited":
            metricKey = "overhead_top_elbow_angle"
        case "overhead_wrist_asymmetry":
            metricKey = "overhead_wrist_asymmetry"
        case "overhead_torso_lean":
            metricKey = "overhead_torso_lean"
        default:
            metricKey = nil
        }
        guard let key = metricKey, let metric = metrics[key] else { return "" }
        return " (\(metric.label) \(formatted(metric)))"
    }

    private func formatted(_ metric: FormMetric) -> String {
        switch metric.unit {
        case "degrees":
            return String(format: "%.0f°", metric.value)
        case "frames":
            return String(format: "%.0f", metric.value)
        default:
            return String(format: "%.2f", metric.value)
        }
    }

    private func prefix(_ key: String, fallback: String, text: String) -> String {
        "\(localize(key, fallback: fallback))：\(text)"
    }

    private func localize(_ key: String, fallback: String) -> String {
        Self.localize(key, fallback: fallback)
    }

    static func localize(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: fallback, comment: "")
    }
}
