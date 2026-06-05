import Foundation

enum PoseFrameQualityPolicy {
    static let minimumJointCount = 6
    static let minimumAverageConfidence = 0.35
    static let minimumBoundingBoxArea = 0.035
    static let minimumBoundingBoxSpan = 0.16

    static func isUsableForFormAnalysis(_ frame: PoseFrame) -> Bool {
        let points = frame.joints.values.filter { $0.confidence >= 0.25 }
        guard points.count >= minimumJointCount else { return false }

        let averageConfidence = points.map(\.confidence).reduce(0, +) / Double(points.count)
        guard averageConfidence >= minimumAverageConfidence else { return false }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return false
        }

        let width = maxX - minX
        let height = maxY - minY
        let area = width * height

        return area >= minimumBoundingBoxArea
            && max(width, height) >= minimumBoundingBoxSpan
    }
}
