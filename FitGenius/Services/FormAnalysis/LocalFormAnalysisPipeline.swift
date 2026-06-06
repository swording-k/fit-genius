import Foundation

struct LocalFormAnalysisArtifact {
    let summary: FormAnalysisSummary
    let feedbackImageData: Data
    let duration: Double
    let feedbackTimestamp: Double
    let classification: FormExerciseClassification
    let usedAutomaticDetection: Bool
}

struct LocalFormAnalysisPipeline {
    private let extractor = PoseExtractionService()
    private let ruleEngine = FormRuleEngine()
    private let classifier = FormExerciseClassifier()
    private let feedbackPlanner = PoseFeedbackPlanner()
    private let overlayRenderer = PoseOverlayRenderer()

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

        return LocalFormAnalysisArtifact(
            summary: summary,
            feedbackImageData: feedbackImage,
            duration: sequence.duration,
            feedbackTimestamp: feedbackPlan.frame.timestamp,
            classification: classification,
            usedAutomaticDetection: preferredExercise == nil
        )
    }
}
