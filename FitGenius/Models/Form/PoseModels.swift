import Foundation

enum FormExerciseType: String, Codable, CaseIterable, Identifiable {
    case squat = "深蹲"
    case deadlift = "硬拉"
    case benchPress = "卧推"
    case overheadPress = "站姿推举"

    var id: String { rawValue }

    var displayName: String { NSLocalizedString(localizationKey, comment: "") }

    var syncIdentifier: String {
        switch self {
        case .squat:
            return "squat"
        case .deadlift:
            return "deadlift"
        case .benchPress:
            return "bench_press"
        case .overheadPress:
            return "overhead_press"
        }
    }

    var localizationKey: String {
        switch self {
        case .squat:
            return "form_exercise_squat"
        case .deadlift:
            return "form_exercise_deadlift"
        case .benchPress:
            return "form_exercise_bench_press"
        case .overheadPress:
            return "form_exercise_overhead_press"
        }
    }

    static func infer(from exerciseName: String) -> FormExerciseType? {
        let name = exerciseName.lowercased()
        if name.contains("深蹲") || name.contains("squat") {
            return .squat
        }
        if name.contains("硬拉") || name.contains("deadlift") {
            return .deadlift
        }
        if name.contains("推举") || name.contains("肩推") || name.contains("overhead") || name.contains("military press") {
            return .overheadPress
        }
        if name.contains("卧推") || name.contains("bench") || name.contains("press") {
            return .benchPress
        }
        return nil
    }
}

enum JointName: String, Codable, CaseIterable, Hashable {
    case nose
    case neck
    case root
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle
}

struct JointPoint: Codable, Hashable {
    let x: Double
    let y: Double
    let confidence: Double

    init(x: Double, y: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

struct PoseFrame: Codable, Hashable {
    let timestamp: Double
    let joints: [JointName: JointPoint]

    init(timestamp: Double, joints: [JointName: JointPoint]) {
        self.timestamp = timestamp
        self.joints = joints
    }

    nonisolated func point(_ joint: JointName, minConfidence: Double = 0.25) -> JointPoint? {
        guard let point = joints[joint], point.confidence >= minConfidence else { return nil }
        return point
    }
}

struct PoseSequence: Codable, Hashable {
    let frames: [PoseFrame]

    init(frames: [PoseFrame]) {
        self.frames = frames
    }

    nonisolated var duration: Double {
        guard let first = frames.first?.timestamp, let last = frames.last?.timestamp else { return 0 }
        return max(0, last - first)
    }
}

struct FormMetric: Codable, Hashable {
    let key: String
    let label: String
    let value: Double
    let unit: String
}

struct FormIssue: Codable, Hashable {
    let code: String
    let title: String
    let detail: String
    let severity: Int
}

struct FormAnalysisSummary: Codable, Hashable {
    let exerciseType: FormExerciseType
    let score: Int
    let issues: [FormIssue]
    let metrics: [FormMetric]
    let recommendation: String
}

enum PoseFixtureQuality {
    case good
    case risky
}

extension PoseSequence {
    static func exerciseFixture(_ exercise: FormExerciseType, quality: PoseFixtureQuality) -> PoseSequence {
        switch exercise {
        case .squat:
            return squatFixture(quality: quality)
        case .deadlift:
            return hingeFixture(quality: quality)
        case .benchPress:
            return pressFixture(quality: quality)
        case .overheadPress:
            return overheadPressFixture(quality: quality)
        }
    }

    private static func squatFixture(quality: PoseFixtureQuality) -> PoseSequence {
        let bottomHipY = quality == .good ? 0.42 : 0.62
        let bottomKneeY = 0.50
        let leftKneeX = quality == .good ? 0.42 : 0.47
        let rightKneeX = quality == .good ? 0.58 : 0.53
        return PoseSequence(frames: [
            standingFrame(timestamp: 0),
            PoseFrame(timestamp: 0.8, joints: [
                .leftShoulder: JointPoint(x: 0.43, y: 0.78, confidence: 0.95),
                .rightShoulder: JointPoint(x: 0.57, y: 0.78, confidence: 0.95),
                .leftHip: JointPoint(x: 0.43, y: bottomHipY, confidence: 0.95),
                .rightHip: JointPoint(x: 0.57, y: bottomHipY, confidence: 0.95),
                .leftKnee: JointPoint(x: leftKneeX, y: bottomKneeY, confidence: 0.95),
                .rightKnee: JointPoint(x: rightKneeX, y: bottomKneeY, confidence: 0.95),
                .leftAnkle: JointPoint(x: 0.40, y: 0.20, confidence: 0.95),
                .rightAnkle: JointPoint(x: 0.60, y: 0.20, confidence: 0.95)
            ]),
            standingFrame(timestamp: 1.6)
        ])
    }

    private static func hingeFixture(quality: PoseFixtureQuality) -> PoseSequence {
        let shoulderX = quality == .good ? 0.48 : 0.36
        return PoseSequence(frames: [
            standingFrame(timestamp: 0),
            PoseFrame(timestamp: 0.8, joints: [
                .leftShoulder: JointPoint(x: shoulderX, y: 0.70, confidence: 0.95),
                .rightShoulder: JointPoint(x: shoulderX + 0.10, y: 0.70, confidence: 0.95),
                .leftHip: JointPoint(x: 0.44, y: 0.50, confidence: 0.95),
                .rightHip: JointPoint(x: 0.56, y: 0.50, confidence: 0.95),
                .leftKnee: JointPoint(x: 0.43, y: 0.34, confidence: 0.95),
                .rightKnee: JointPoint(x: 0.57, y: 0.34, confidence: 0.95),
                .leftAnkle: JointPoint(x: 0.42, y: 0.18, confidence: 0.95),
                .rightAnkle: JointPoint(x: 0.58, y: 0.18, confidence: 0.95)
            ])
        ])
    }

    private static func pressFixture(quality: PoseFixtureQuality) -> PoseSequence {
        let elbowY = quality == .good ? 0.50 : 0.36
        return PoseSequence(frames: [
            PoseFrame(timestamp: 0, joints: [
                .leftShoulder: JointPoint(x: 0.36, y: 0.56, confidence: 0.95),
                .rightShoulder: JointPoint(x: 0.64, y: 0.56, confidence: 0.95),
                .leftElbow: JointPoint(x: 0.30, y: elbowY, confidence: 0.95),
                .rightElbow: JointPoint(x: 0.70, y: elbowY, confidence: 0.95),
                .leftWrist: JointPoint(x: 0.28, y: 0.70, confidence: 0.95),
                .rightWrist: JointPoint(x: 0.72, y: 0.70, confidence: 0.95)
            ])
        ])
    }

    private static func overheadPressFixture(quality: PoseFixtureQuality) -> PoseSequence {
        let topLeftWristY = quality == .good ? 0.94 : 0.78
        let topRightWristY = quality == .good ? 0.94 : 0.68
        let shoulderX = quality == .good ? 0.43 : 0.34
        return PoseSequence(frames: [
            PoseFrame(timestamp: 0, joints: [
                .leftShoulder: JointPoint(x: 0.43, y: 0.75, confidence: 0.95),
                .rightShoulder: JointPoint(x: 0.57, y: 0.75, confidence: 0.95),
                .leftElbow: JointPoint(x: 0.40, y: 0.68, confidence: 0.95),
                .rightElbow: JointPoint(x: 0.60, y: 0.68, confidence: 0.95),
                .leftWrist: JointPoint(x: 0.42, y: 0.75, confidence: 0.95),
                .rightWrist: JointPoint(x: 0.58, y: 0.75, confidence: 0.95),
                .leftHip: JointPoint(x: 0.44, y: 0.50, confidence: 0.95),
                .rightHip: JointPoint(x: 0.56, y: 0.50, confidence: 0.95),
                .leftKnee: JointPoint(x: 0.44, y: 0.30, confidence: 0.95),
                .rightKnee: JointPoint(x: 0.56, y: 0.30, confidence: 0.95),
                .leftAnkle: JointPoint(x: 0.43, y: 0.12, confidence: 0.95),
                .rightAnkle: JointPoint(x: 0.57, y: 0.12, confidence: 0.95)
            ]),
            PoseFrame(timestamp: 0.8, joints: [
                .leftShoulder: JointPoint(x: shoulderX, y: 0.75, confidence: 0.95),
                .rightShoulder: JointPoint(x: shoulderX + 0.14, y: 0.75, confidence: 0.95),
                .leftElbow: JointPoint(x: 0.42, y: quality == .good ? 0.85 : 0.72, confidence: 0.95),
                .rightElbow: JointPoint(x: 0.58, y: quality == .good ? 0.85 : 0.70, confidence: 0.95),
                .leftWrist: JointPoint(x: 0.44, y: topLeftWristY, confidence: 0.95),
                .rightWrist: JointPoint(x: 0.56, y: topRightWristY, confidence: 0.95),
                .leftHip: JointPoint(x: 0.44, y: 0.50, confidence: 0.95),
                .rightHip: JointPoint(x: 0.56, y: 0.50, confidence: 0.95),
                .leftKnee: JointPoint(x: 0.44, y: 0.30, confidence: 0.95),
                .rightKnee: JointPoint(x: 0.56, y: 0.30, confidence: 0.95),
                .leftAnkle: JointPoint(x: 0.43, y: 0.12, confidence: 0.95),
                .rightAnkle: JointPoint(x: 0.57, y: 0.12, confidence: 0.95)
            ])
        ])
    }

    private static func standingFrame(timestamp: Double) -> PoseFrame {
        PoseFrame(timestamp: timestamp, joints: [
            .leftShoulder: JointPoint(x: 0.43, y: 0.82, confidence: 0.95),
            .rightShoulder: JointPoint(x: 0.57, y: 0.82, confidence: 0.95),
            .leftHip: JointPoint(x: 0.44, y: 0.56, confidence: 0.95),
            .rightHip: JointPoint(x: 0.56, y: 0.56, confidence: 0.95),
            .leftKnee: JointPoint(x: 0.44, y: 0.36, confidence: 0.95),
            .rightKnee: JointPoint(x: 0.56, y: 0.36, confidence: 0.95),
            .leftAnkle: JointPoint(x: 0.42, y: 0.18, confidence: 0.95),
            .rightAnkle: JointPoint(x: 0.58, y: 0.18, confidence: 0.95)
        ])
    }
}
