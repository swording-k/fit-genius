import Foundation

struct FormRuleEngine {
    func analyze(exercise: FormExerciseType, sequence: PoseSequence) -> FormAnalysisSummary {
        switch exercise {
        case .squat:
            return analyzeSquat(sequence)
        case .deadlift:
            return analyzeDeadlift(sequence)
        case .benchPress:
            return analyzeBenchPress(sequence)
        }
    }

    private func analyzeSquat(_ sequence: PoseSequence) -> FormAnalysisSummary {
        var issues = baseIssues(exercise: .squat, sequence: sequence)
        var metrics: [FormMetric] = baseMetrics(exercise: .squat, sequence: sequence)

        let hipToKneeDelta = minHipToKneeDelta(sequence)
        metrics.append(FormMetric(key: "squat_depth_delta", label: localized("form_metric_squat_depth_delta"), value: hipToKneeDelta, unit: "norm"))
        if hipToKneeDelta > 0.08 {
            issues.append(FormIssue(
                code: "squat_depth_limited",
                title: localized("form_issue_squat_depth_limited_title"),
                detail: localized("form_issue_squat_depth_limited_detail"),
                severity: 2
            ))
        }

        let kneeCave = maxKneeCave(sequence)
        metrics.append(FormMetric(key: "squat_knee_cave", label: localized("form_metric_squat_knee_cave"), value: kneeCave, unit: "norm"))
        if kneeCave > 0.035 {
            issues.append(FormIssue(
                code: "squat_knee_cave",
                title: localized("form_issue_squat_knee_cave_title"),
                detail: localized("form_issue_squat_knee_cave_detail"),
                severity: 3
            ))
        }

        let torsoLean = averageTorsoLean(sequence)
        metrics.append(FormMetric(key: "torso_lean", label: localized("form_metric_torso_lean"), value: torsoLean, unit: "norm"))
        if torsoLean > 0.20 {
            issues.append(FormIssue(
                code: "squat_torso_lean",
                title: localized("form_issue_squat_torso_lean_title"),
                detail: localized("form_issue_squat_torso_lean_detail"),
                severity: 2
            ))
        }

        return summary(
            exercise: .squat,
            issues: issues,
            metrics: metrics,
            fallbackRecommendation: localized("form_recommendation_squat")
        )
    }

    private func analyzeDeadlift(_ sequence: PoseSequence) -> FormAnalysisSummary {
        var issues = baseIssues(exercise: .deadlift, sequence: sequence)
        var metrics: [FormMetric] = baseMetrics(exercise: .deadlift, sequence: sequence)

        let torsoLean = averageTorsoLean(sequence)
        metrics.append(FormMetric(key: "deadlift_back_angle", label: localized("form_metric_deadlift_back_angle"), value: torsoLean, unit: "norm"))
        if torsoLean > 0.24 {
            issues.append(FormIssue(
                code: "deadlift_back_position",
                title: localized("form_issue_deadlift_back_position_title"),
                detail: localized("form_issue_deadlift_back_position_detail"),
                severity: 3
            ))
        }

        let kneeTravel = maxKneeCave(sequence)
        metrics.append(FormMetric(key: "deadlift_knee_track", label: localized("form_metric_deadlift_knee_track"), value: kneeTravel, unit: "norm"))
        if kneeTravel > 0.045 {
            issues.append(FormIssue(
                code: "deadlift_knee_track",
                title: localized("form_issue_deadlift_knee_track_title"),
                detail: localized("form_issue_deadlift_knee_track_detail"),
                severity: 2
            ))
        }

        return summary(
            exercise: .deadlift,
            issues: issues,
            metrics: metrics,
            fallbackRecommendation: localized("form_recommendation_deadlift")
        )
    }

    private func analyzeBenchPress(_ sequence: PoseSequence) -> FormAnalysisSummary {
        var issues = baseIssues(exercise: .benchPress, sequence: sequence)
        var metrics: [FormMetric] = baseMetrics(exercise: .benchPress, sequence: sequence)

        let elbowFlare = averageElbowFlare(sequence)
        metrics.append(FormMetric(key: "bench_elbow_flare", label: localized("form_metric_bench_elbow_flare"), value: elbowFlare, unit: "norm"))
        if elbowFlare > 0.16 {
            issues.append(FormIssue(
                code: "bench_elbow_flare",
                title: localized("form_issue_bench_elbow_flare_title"),
                detail: localized("form_issue_bench_elbow_flare_detail"),
                severity: 2
            ))
        }

        let wristAsymmetry = averageWristAsymmetry(sequence)
        metrics.append(FormMetric(key: "bench_asymmetry", label: localized("form_metric_bench_asymmetry"), value: wristAsymmetry, unit: "norm"))
        if wristAsymmetry > 0.06 {
            issues.append(FormIssue(
                code: "bench_press_asymmetry",
                title: localized("form_issue_bench_press_asymmetry_title"),
                detail: localized("form_issue_bench_press_asymmetry_detail"),
                severity: 2
            ))
        }

        let wristPath = wristPathVariation(sequence)
        metrics.append(FormMetric(key: "bench_wrist_path", label: localized("form_metric_bench_wrist_path"), value: wristPath, unit: "norm"))
        if wristPath > 0.10 {
            issues.append(FormIssue(
                code: "bench_wrist_path",
                title: localized("form_issue_bench_wrist_path_title"),
                detail: localized("form_issue_bench_wrist_path_detail"),
                severity: 2
            ))
        }

        let rangeOfMotion = benchRangeOfMotion(sequence)
        metrics.append(FormMetric(key: "bench_range_of_motion", label: localized("form_metric_bench_range_of_motion"), value: rangeOfMotion, unit: "norm"))
        if sequence.frames.count >= 3, rangeOfMotion < 0.06 {
            issues.append(FormIssue(
                code: "bench_limited_range",
                title: localized("form_issue_bench_limited_range_title"),
                detail: localized("form_issue_bench_limited_range_detail"),
                severity: 2
            ))
        }

        let cameraAngle = benchCameraAngleQuality(sequence)
        metrics.append(FormMetric(key: "bench_camera_angle", label: localized("form_metric_bench_camera_angle"), value: cameraAngle, unit: "0-1"))
        if cameraAngle < 0.45 {
            issues.append(FormIssue(
                code: "bench_camera_angle_limited",
                title: localized("form_issue_bench_camera_angle_limited_title"),
                detail: localized("form_issue_bench_camera_angle_limited_detail"),
                severity: 1
            ))
        }

        return summary(
            exercise: .benchPress,
            issues: issues,
            metrics: metrics,
            fallbackRecommendation: localized("form_recommendation_bench")
        )
    }

    private func summary(
        exercise: FormExerciseType,
        issues: [FormIssue],
        metrics: [FormMetric],
        fallbackRecommendation: String
    ) -> FormAnalysisSummary {
        let penalty = issues.reduce(0) { $0 + max(8, $1.severity * 10) }
        let score = max(45, min(98, 96 - penalty))
        let recommendation: String
        if issues.isEmpty {
            recommendation = localized("form_recommendation_stable")
        } else {
            recommendation = fallbackRecommendation
        }

        return FormAnalysisSummary(
            exerciseType: exercise,
            score: score,
            issues: Array(issues.prefix(3)),
            metrics: metrics,
            recommendation: recommendation
        )
    }

    private func minHipToKneeDelta(_ sequence: PoseSequence) -> Double {
        let values: [Double] = sequence.frames.compactMap { frame in
            guard let hip = averagePoint(frame, .leftHip, .rightHip),
                  let knee = averagePoint(frame, .leftKnee, .rightKnee) else { return nil }
            return hip.y - knee.y
        }
        return values.min() ?? 0
    }

    private func maxKneeCave(_ sequence: PoseSequence) -> Double {
        let values: [Double] = sequence.frames.compactMap { frame in
            guard let leftKnee = frame.point(.leftKnee),
                  let rightKnee = frame.point(.rightKnee),
                  let leftAnkle = frame.point(.leftAnkle),
                  let rightAnkle = frame.point(.rightAnkle) else { return nil }
            let left = abs(leftKnee.x - leftAnkle.x)
            let right = abs(rightKnee.x - rightAnkle.x)
            return max(0, ((left + right) / 2.0) - 0.025)
        }
        return values.max() ?? 0
    }

    private func averageTorsoLean(_ sequence: PoseSequence) -> Double {
        average(sequence.frames.compactMap { frame in
            guard let shoulder = averagePoint(frame, .leftShoulder, .rightShoulder),
                  let hip = averagePoint(frame, .leftHip, .rightHip) else { return nil }
            return abs(shoulder.x - hip.x)
        })
    }

    private func averageElbowFlare(_ sequence: PoseSequence) -> Double {
        average(sequence.frames.compactMap { frame in
            guard let leftShoulder = frame.point(.leftShoulder),
                  let rightShoulder = frame.point(.rightShoulder),
                  let leftElbow = frame.point(.leftElbow),
                  let rightElbow = frame.point(.rightElbow) else { return nil }
            let left = abs(leftElbow.x - leftShoulder.x)
            let right = abs(rightElbow.x - rightShoulder.x)
            return (left + right) / 2.0
        })
    }

    private func averageWristAsymmetry(_ sequence: PoseSequence) -> Double {
        average(sequence.frames.compactMap { frame in
            guard let left = frame.point(.leftWrist), let right = frame.point(.rightWrist) else { return nil }
            return abs(left.y - right.y)
        })
    }

    private func wristPathVariation(_ sequence: PoseSequence) -> Double {
        let midpoints: [JointPoint] = sequence.frames.compactMap { frame in
            averagePoint(frame, .leftWrist, .rightWrist)
        }
        guard let first = midpoints.first, midpoints.count > 1 else { return 0 }
        return average(midpoints.map { abs($0.x - first.x) + abs($0.y - first.y) })
    }

    private func benchRangeOfMotion(_ sequence: PoseSequence) -> Double {
        let wristYValues: [Double] = sequence.frames.compactMap { frame in
            averagePoint(frame, .leftWrist, .rightWrist)?.y
        }
        guard let minY = wristYValues.min(), let maxY = wristYValues.max() else { return 0 }
        return maxY - minY
    }

    private func benchCameraAngleQuality(_ sequence: PoseSequence) -> Double {
        let widths: [Double] = sequence.frames.compactMap { frame in
            guard let leftShoulder = frame.point(.leftShoulder),
                  let rightShoulder = frame.point(.rightShoulder),
                  let leftWrist = frame.point(.leftWrist),
                  let rightWrist = frame.point(.rightWrist) else { return nil }
            let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
            let wristWidth = abs(leftWrist.x - rightWrist.x)
            return (shoulderWidth + wristWidth) / 2.0
        }
        return min(1.0, average(widths) / 0.24)
    }

    private func baseMetrics(exercise: FormExerciseType, sequence: PoseSequence) -> [FormMetric] {
        let poseQuality = poseQuality(exercise: exercise, sequence: sequence)
        return [
            FormMetric(key: "pose_quality", label: localized("form_metric_pose_quality"), value: poseQuality, unit: "0-1"),
            FormMetric(key: "detected_frames", label: localized("form_metric_detected_frames"), value: Double(sequence.frames.count), unit: "frames")
        ]
    }

    private func baseIssues(exercise: FormExerciseType, sequence: PoseSequence) -> [FormIssue] {
        let quality = poseQuality(exercise: exercise, sequence: sequence)
        guard quality < 0.80 else { return [] }
        return [
            FormIssue(
                code: "pose_quality_low",
                title: localized("form_issue_pose_quality_low_title"),
                detail: localized("form_issue_pose_quality_low_detail"),
                severity: 2
            )
        ]
    }

    private func poseQuality(exercise: FormExerciseType, sequence: PoseSequence) -> Double {
        let requiredJoints = requiredJoints(for: exercise)
        guard !requiredJoints.isEmpty else { return 0 }

        let frameScores = sequence.frames.map { frame in
            let detectedCount = requiredJoints.filter { frame.point($0) != nil }.count
            return Double(detectedCount) / Double(requiredJoints.count)
        }
        return min(1.0, average(frameScores))
    }

    private func requiredJoints(for exercise: FormExerciseType) -> [JointName] {
        switch exercise {
        case .squat, .deadlift:
            return [
                .leftShoulder, .rightShoulder,
                .leftHip, .rightHip,
                .leftKnee, .rightKnee,
                .leftAnkle, .rightAnkle
            ]
        case .benchPress:
            return [
                .leftShoulder, .rightShoulder,
                .leftElbow, .rightElbow,
                .leftWrist, .rightWrist
            ]
        }
    }

    private func averagePoint(_ frame: PoseFrame, _ left: JointName, _ right: JointName) -> JointPoint? {
        guard let leftPoint = frame.point(left), let rightPoint = frame.point(right) else { return nil }
        return JointPoint(
            x: (leftPoint.x + rightPoint.x) / 2.0,
            y: (leftPoint.y + rightPoint.y) / 2.0,
            confidence: min(leftPoint.confidence, rightPoint.confidence)
        )
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
