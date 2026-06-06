import Foundation

struct FormAnalysisQualityReport: Hashable {
    let frameCount: Int
    let duration: Double
    let averageJointCount: Double
    let averageConfidence: Double
    let averageBodyArea: Double
    let motionAmount: Double

    var isUsable: Bool {
        frameCount >= 3
            && duration >= 1.0
            && averageJointCount >= 7
            && averageConfidence >= 0.42
            && averageBodyArea >= 0.045
            && motionAmount >= 0.025
    }
}

enum FormAnalysisQualityGate {
    nonisolated static func report(for sequence: PoseSequence) -> FormAnalysisQualityReport {
        let frames = sequence.frames
        let areas = frames.map(bodyArea)
        let confidences = frames.flatMap { $0.joints.values.map(\.confidence) }
        let jointCounts = frames.map { Double($0.joints.count) }
        return FormAnalysisQualityReport(
            frameCount: frames.count,
            duration: sequence.duration,
            averageJointCount: average(jointCounts),
            averageConfidence: average(confidences),
            averageBodyArea: average(areas),
            motionAmount: motionAmount(frames)
        )
    }

    private nonisolated static func bodyArea(_ frame: PoseFrame) -> Double {
        let points = frame.joints.values.filter { $0.confidence >= 0.25 }
        guard let minX = points.map(\.x).min(),
              let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(),
              let maxY = points.map(\.y).max() else {
            return 0
        }
        return max(0, maxX - minX) * max(0, maxY - minY)
    }

    private nonisolated static func motionAmount(_ frames: [PoseFrame]) -> Double {
        guard let first = frames.first, frames.count > 1 else { return 0 }
        let commonJoints = first.joints.keys.filter { joint in
            frames.allSatisfy { $0.point(joint) != nil }
        }
        guard !commonJoints.isEmpty else { return 0 }

        let jointMotions = commonJoints.compactMap { joint -> Double? in
            guard let origin = first.point(joint) else { return nil }
            return frames.compactMap { frame -> Double? in
                guard let point = frame.point(joint) else { return nil }
                return hypot(point.x - origin.x, point.y - origin.y)
            }.max()
        }
        return average(jointMotions)
    }

    private nonisolated static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
