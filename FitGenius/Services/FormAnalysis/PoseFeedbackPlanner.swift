import Foundation

struct PoseSegment: Hashable {
    let start: JointName
    let end: JointName
}

struct PoseFeedbackPlan: Hashable {
    let frame: PoseFrame
    let segments: [PoseSegment]
    let highlightedJoints: Set<JointName>
    let annotations: [PoseIssueAnnotation]
}

struct PoseIssueAnnotation: Hashable {
    let title: String
    let severity: Int
    let joints: [JointName]
}

struct PoseFeedbackPlanner {
    private let skeletonSegments = [
        PoseSegment(start: .leftShoulder, end: .rightShoulder),
        PoseSegment(start: .leftShoulder, end: .leftElbow),
        PoseSegment(start: .leftElbow, end: .leftWrist),
        PoseSegment(start: .rightShoulder, end: .rightElbow),
        PoseSegment(start: .rightElbow, end: .rightWrist),
        PoseSegment(start: .leftShoulder, end: .leftHip),
        PoseSegment(start: .rightShoulder, end: .rightHip),
        PoseSegment(start: .leftHip, end: .rightHip),
        PoseSegment(start: .leftHip, end: .leftKnee),
        PoseSegment(start: .leftKnee, end: .leftAnkle),
        PoseSegment(start: .rightHip, end: .rightKnee),
        PoseSegment(start: .rightKnee, end: .rightAnkle)
    ]

    func makePlan(
        exercise: FormExerciseType,
        sequence: PoseSequence,
        issues: [FormIssue]
    ) -> PoseFeedbackPlan {
        let frame = representativeFrame(for: exercise, sequence: sequence)
        let visibleSegments = skeletonSegments.filter {
            frame.point($0.start) != nil && frame.point($0.end) != nil
        }
        let annotations = issues.compactMap { issue -> PoseIssueAnnotation? in
            let joints = highlightedJoints(for: issue.code)
            guard !joints.isEmpty else { return nil }
            return PoseIssueAnnotation(title: issue.title, severity: issue.severity, joints: joints)
        }
        let highlights = Set(annotations.flatMap(\.joints))
        return PoseFeedbackPlan(
            frame: frame,
            segments: visibleSegments,
            highlightedJoints: highlights,
            annotations: annotations
        )
    }

    private func representativeFrame(
        for exercise: FormExerciseType,
        sequence: PoseSequence
    ) -> PoseFrame {
        let candidateFrames = sequence.frames.filter {
            PoseFrameQualityPolicy.isUsableForFormAnalysis($0)
        }
        let frames = candidateFrames.isEmpty ? sequence.frames : candidateFrames

        guard let fallback = frames.max(by: { $0.joints.count < $1.joints.count }) else {
            return PoseFrame(timestamp: 0, joints: [:])
        }

        switch exercise {
        case .squat:
            return frames.min(by: {
                averageY($0, .leftHip, .rightHip) > averageY($1, .leftHip, .rightHip)
            }) ?? fallback
        case .deadlift:
            return frames.max(by: {
                torsoLean($0) < torsoLean($1)
            }) ?? fallback
        case .benchPress:
            return frames.min(by: {
                averageY($0, .leftWrist, .rightWrist) > averageY($1, .leftWrist, .rightWrist)
            }) ?? fallback
        case .overheadPress:
            return frames.max(by: {
                averageY($0, .leftWrist, .rightWrist) < averageY($1, .leftWrist, .rightWrist)
            }) ?? fallback
        }
    }

    private func highlightedJoints(for issueCode: String) -> [JointName] {
        if issueCode.contains("knee") {
            return [.leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
        }
        if issueCode.contains("elbow") {
            return [.leftShoulder, .rightShoulder, .leftElbow, .rightElbow]
        }
        if issueCode.contains("lockout") {
            return [.leftElbow, .rightElbow, .leftWrist, .rightWrist]
        }
        if issueCode.contains("wrist") || issueCode.contains("asymmetry") {
            return [.leftWrist, .rightWrist]
        }
        if issueCode.contains("back") || issueCode.contains("torso") {
            return [.leftShoulder, .rightShoulder, .leftHip, .rightHip]
        }
        if issueCode.contains("depth") || issueCode.contains("range") {
            return [.leftHip, .rightHip, .leftKnee, .rightKnee]
        }
        return []
    }

    private func averageY(_ frame: PoseFrame, _ left: JointName, _ right: JointName) -> Double {
        let values = [frame.point(left)?.y, frame.point(right)?.y].compactMap { $0 }
        guard !values.isEmpty else { return 1 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func torsoLean(_ frame: PoseFrame) -> Double {
        guard let leftShoulder = frame.point(.leftShoulder),
              let rightShoulder = frame.point(.rightShoulder),
              let leftHip = frame.point(.leftHip),
              let rightHip = frame.point(.rightHip) else { return 0 }
        let shoulderX = (leftShoulder.x + rightShoulder.x) / 2
        let hipX = (leftHip.x + rightHip.x) / 2
        return abs(shoulderX - hipX)
    }
}
