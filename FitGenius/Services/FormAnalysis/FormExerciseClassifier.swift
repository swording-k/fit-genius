import Foundation

struct FormExerciseClassification: Hashable {
    let exercise: FormExerciseType
    let confidence: Double
    let reasonKey: String
    let isReliable: Bool
}

struct FormExerciseClassifier {
    func classify(_ sequence: PoseSequence) -> FormExerciseClassification {
        let upperBodyCoverage = coverage(
            [.leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist],
            in: sequence
        )
        let lowerBodyCoverage = coverage(
            [.leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle],
            in: sequence
        )
        let horizontalTorsoRatio = averageHorizontalTorsoRatio(sequence)

        if upperBodyCoverage >= 0.65,
           lowerBodyCoverage < 0.45 || horizontalTorsoRatio >= 1.2 {
            let confidence = min(0.95, 0.62 + upperBodyCoverage * 0.2 + max(0, 0.45 - lowerBodyCoverage) * 0.3)
            return FormExerciseClassification(
                exercise: .benchPress,
                confidence: confidence,
                reasonKey: "form_detection_reason_bench",
                isReliable: true
            )
        }

        let overheadRatio = overheadWristRatio(sequence)
        if upperBodyCoverage >= 0.65,
           lowerBodyCoverage >= 0.45,
           overheadRatio >= 0.45 {
            return FormExerciseClassification(
                exercise: .overheadPress,
                confidence: min(0.93, 0.66 + overheadRatio * 0.24),
                reasonKey: "form_detection_reason_overhead_press",
                isReliable: true
            )
        }

        let depthDelta = minHipToKneeDelta(sequence)
        if depthDelta <= 0.08 {
            let confidence = min(0.92, 0.68 + max(0, 0.08 - depthDelta))
            return FormExerciseClassification(
                exercise: .squat,
                confidence: confidence,
                reasonKey: "form_detection_reason_squat",
                isReliable: true
            )
        }

        let lean = maxTorsoLean(sequence)
        let hipTravel = hipVerticalTravel(sequence)
        let isReliable = lowerBodyCoverage >= 0.60 && lean >= 0.02 && hipTravel >= 0.04
        let confidence = isReliable ? min(0.9, 0.62 + lean + hipTravel) : 0.35
        return FormExerciseClassification(
            exercise: .deadlift,
            confidence: confidence,
            reasonKey: isReliable ? "form_detection_reason_deadlift" : "form_detection_reason_uncertain",
            isReliable: isReliable
        )
    }

    private func coverage(_ joints: [JointName], in sequence: PoseSequence) -> Double {
        guard !sequence.frames.isEmpty, !joints.isEmpty else { return 0 }
        let scores = sequence.frames.map { frame in
            Double(joints.filter { frame.point($0) != nil }.count) / Double(joints.count)
        }
        return average(scores)
    }

    private func averageHorizontalTorsoRatio(_ sequence: PoseSequence) -> Double {
        average(sequence.frames.compactMap { frame in
            guard let shoulder = midpoint(frame, .leftShoulder, .rightShoulder),
                  let hip = midpoint(frame, .leftHip, .rightHip) else { return nil }
            let horizontal = abs(shoulder.x - hip.x)
            let vertical = max(0.01, abs(shoulder.y - hip.y))
            return horizontal / vertical
        })
    }

    private func minHipToKneeDelta(_ sequence: PoseSequence) -> Double {
        sequence.frames.compactMap { frame in
            guard let hip = midpoint(frame, .leftHip, .rightHip),
                  let knee = midpoint(frame, .leftKnee, .rightKnee) else { return nil }
            return hip.y - knee.y
        }.min() ?? 1
    }

    private func overheadWristRatio(_ sequence: PoseSequence) -> Double {
        let matches = sequence.frames.compactMap { frame -> Bool? in
            guard let shoulder = midpoint(frame, .leftShoulder, .rightShoulder),
                  let wrist = midpoint(frame, .leftWrist, .rightWrist) else { return nil }
            return wrist.y > shoulder.y + 0.04
        }
        guard !matches.isEmpty else { return 0 }
        return Double(matches.filter { $0 }.count) / Double(matches.count)
    }

    private func maxTorsoLean(_ sequence: PoseSequence) -> Double {
        sequence.frames.compactMap { frame in
            guard let shoulder = midpoint(frame, .leftShoulder, .rightShoulder),
                  let hip = midpoint(frame, .leftHip, .rightHip) else { return nil }
            return abs(shoulder.x - hip.x)
        }.max() ?? 0
    }

    private func hipVerticalTravel(_ sequence: PoseSequence) -> Double {
        let values = sequence.frames.compactMap { midpoint($0, .leftHip, .rightHip)?.y }
        guard let minimum = values.min(), let maximum = values.max() else { return 0 }
        return maximum - minimum
    }

    private func midpoint(_ frame: PoseFrame, _ left: JointName, _ right: JointName) -> JointPoint? {
        guard let left = frame.point(left), let right = frame.point(right) else { return nil }
        return JointPoint(
            x: (left.x + right.x) / 2,
            y: (left.y + right.y) / 2,
            confidence: min(left.confidence, right.confidence)
        )
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
