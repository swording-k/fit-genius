import Foundation

/// Pure time mapping for two manually aligned exercise videos.
/// Both players advance over the same shared duration after their own offsets.
struct VideoComparisonTimeline: Equatable {
    static let supportedRates: [Double] = [0.25, 0.5, 1.0]

    let referenceDuration: Double
    let userDuration: Double
    let referenceOffset: Double
    let userOffset: Double

    private var safeReferenceDuration: Double { max(0, referenceDuration) }
    private var safeUserDuration: Double { max(0, userDuration) }
    private var safeReferenceOffset: Double { min(max(0, referenceOffset), safeReferenceDuration) }
    private var safeUserOffset: Double { min(max(0, userOffset), safeUserDuration) }

    var commonDuration: Double {
        min(
            max(0, safeReferenceDuration - safeReferenceOffset),
            max(0, safeUserDuration - safeUserOffset)
        )
    }

    func referenceTime(progress: Double) -> Double {
        min(safeReferenceDuration, safeReferenceOffset + clampedProgress(progress) * commonDuration)
    }

    func userTime(progress: Double) -> Double {
        min(safeUserDuration, safeUserOffset + clampedProgress(progress) * commonDuration)
    }

    func clampedRate(_ proposed: Double) -> Double {
        Self.supportedRates.min { abs($0 - proposed) < abs($1 - proposed) } ?? 1.0
    }

    private func clampedProgress(_ progress: Double) -> Double {
        min(max(0, progress), 1)
    }
}
