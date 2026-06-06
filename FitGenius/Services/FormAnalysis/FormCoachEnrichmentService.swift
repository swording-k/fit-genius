import Foundation

struct FormCoachEnrichmentService {
    private let overlayRenderer = PoseOverlayRenderer()

    @MainActor
    func enrich(
        summary: FormAnalysisSummary,
        frameBundles: [PoseFrameBundle],
        feedbackTimestamp: Double
    ) async throws -> FormCoachEnrichmentArtifact {
        guard frameBundles.count >= 2 else {
            throw FormCoachEnrichmentError.notEnoughFrames
        }

        let result = try await AIService().enrichFormFeedback(
            summary: summary,
            skeletonImages: frameBundles.map(\.skeletonImageData),
            feedbackTimestamp: feedbackTimestamp
        )

        let selectedIndexes = usableIndexes(
            result.selectedFrameIndexes,
            frameCount: frameBundles.count
        )
        let fallbackIndexes = selectedIndexes.isEmpty ? Array(0..<min(2, frameBundles.count)) : selectedIndexes

        var annotatedImages: [Data] = []
        for index in fallbackIndexes.prefix(2) {
            let annotations = result.annotations.filter { $0.imageIndex == index }
            let data = try await overlayRenderer.renderSkeletonFrame(
                poseFrame: frameBundles[index].frame,
                index: index,
                total: frameBundles.count,
                annotations: annotations
            )
            annotatedImages.append(data)
        }

        if annotatedImages.isEmpty {
            throw FormCoachEnrichmentError.noUsableFrame
        }

        return FormCoachEnrichmentArtifact(
            result: result,
            annotatedImageData: annotatedImages
        )
    }

    private func usableIndexes(_ indexes: [Int], frameCount: Int) -> [Int] {
        var seen = Set<Int>()
        return indexes.filter { index in
            guard index >= 0, index < frameCount, !seen.contains(index) else { return false }
            seen.insert(index)
            return true
        }
    }
}
