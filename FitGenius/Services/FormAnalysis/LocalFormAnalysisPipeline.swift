import Foundation

struct LocalFormAnalysisArtifact {
    let summary: FormAnalysisSummary
    let feedbackImageData: Data
    let enrichment: FormCoachEnrichmentArtifact?
    let duration: Double
    let feedbackTimestamp: Double
    let classification: FormExerciseClassification
    let usedAutomaticDetection: Bool
    let enrichmentAttempted: Bool
}

struct LocalFormAnalysisPipeline {
    private let extractor = PoseExtractionService()
    private let ruleEngine = FormRuleEngine()
    private let classifier = FormExerciseClassifier()
    private let feedbackPlanner = PoseFeedbackPlanner()
    private let overlayRenderer = PoseOverlayRenderer()
    private let enrichmentService = FormCoachEnrichmentService()

    func analyze(videoData: Data, preferredExercise: FormExerciseType? = nil) async throws -> LocalFormAnalysisArtifact {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        try videoData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let sequence: PoseSequence
        let shouldApplyQualityGate: Bool
        #if DEBUG && targetEnvironment(simulator)
        if DebugFormAnalysisVideoProvider.launchVideoURL != nil {
            sequence = .exerciseFixture(preferredExercise ?? .benchPress, quality: .risky)
            shouldApplyQualityGate = false
        } else {
            sequence = try await extractor.extractPoseSequence(from: tempURL)
            shouldApplyQualityGate = true
        }
        #else
        sequence = try await extractor.extractPoseSequence(from: tempURL)
        shouldApplyQualityGate = true
        #endif
        let qualityReport = FormAnalysisQualityGate.report(for: sequence)
        if shouldApplyQualityGate, !qualityReport.isUsable {
            throw PoseExtractionError.lowQualityVideo
        }
        let classification = classifier.classify(sequence)
        if preferredExercise == nil, !classification.isReliable {
            throw PoseExtractionError.unsupportedExercise
        }
        let exercise = preferredExercise ?? classification.exercise
        let summary = ruleEngine.analyze(exercise: exercise, sequence: sequence)
        let feedbackPlan = feedbackPlanner.makePlan(
            exercise: exercise,
            sequence: sequence,
            issues: summary.issues
        )
        let feedbackImage = try await overlayRenderer.render(
            videoURL: tempURL,
            plan: feedbackPlan,
            summary: summary
        )
        let (enrichment, enrichmentAttempted) = await runEnrichment(
            summary: summary,
            sequence: sequence,
            feedbackTimestamp: feedbackPlan.frame.timestamp
        )

        return LocalFormAnalysisArtifact(
            summary: summary,
            feedbackImageData: feedbackImage,
            enrichment: enrichment,
            duration: sequence.duration,
            feedbackTimestamp: feedbackPlan.frame.timestamp,
            classification: classification,
            usedAutomaticDetection: preferredExercise == nil,
            enrichmentAttempted: enrichmentAttempted
        )
    }

    private func runEnrichment(
        summary: FormAnalysisSummary,
        sequence: PoseSequence,
        feedbackTimestamp: Double
    ) async -> (FormCoachEnrichmentArtifact?, Bool) {
        let frames = selectCandidateFrames(from: sequence)
        guard frames.count >= 2 else { return (nil, false) }

        var bundles: [PoseFrameBundle] = []
        for (index, frame) in frames.enumerated() {
            do {
                let imageData = try await overlayRenderer.renderSkeletonFrame(
                    poseFrame: frame,
                    index: index,
                    total: frames.count
                )
                bundles.append(PoseFrameBundle(frame: frame, skeletonImageData: imageData))
            } catch {
                continue
            }
        }

        guard bundles.count >= 2 else { return (nil, true) }
        do {
            let artifact = try await enrichmentService.enrich(
                summary: summary,
                frameBundles: bundles,
                feedbackTimestamp: feedbackTimestamp
            )
            return (artifact, true)
        } catch {
            return (nil, true)
        }
    }

    private func selectCandidateFrames(from sequence: PoseSequence) -> [PoseFrame] {
        let usable = sequence.frames.filter { PoseFrameQualityPolicy.isUsableForFormAnalysis($0) }
        let frames = usable.isEmpty ? sequence.frames : usable
        let targetCount = 6
        guard frames.count > targetCount else { return frames }

        var result: [PoseFrame] = []
        for bucket in 0..<targetCount {
            let start = (frames.count * bucket) / targetCount
            let end = max(start + 1, (frames.count * (bucket + 1)) / targetCount)
            let range = start..<min(end, frames.count)
            guard let best = range.max(by: {
                visibleJointCount(frames[$0]) < visibleJointCount(frames[$1])
            }) else { continue }
            result.append(frames[best])
        }
        return result
    }

    private func visibleJointCount(_ frame: PoseFrame) -> Int {
        frame.joints.values.filter { $0.confidence >= 0.25 }.count
    }
}
