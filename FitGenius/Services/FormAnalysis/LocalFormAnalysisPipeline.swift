import Foundation

struct LocalFormAnalysisArtifact {
    let summary: FormAnalysisSummary
    let feedbackImageData: Data
    let duration: Double
    let feedbackTimestamp: Double
}

struct LocalFormAnalysisPipeline {
    private let extractor = PoseExtractionService()
    private let ruleEngine = FormRuleEngine()
    private let feedbackPlanner = PoseFeedbackPlanner()
    private let overlayRenderer = PoseOverlayRenderer()

    func analyze(videoData: Data, exercise: FormExerciseType) async throws -> LocalFormAnalysisArtifact {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        try videoData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let sequence: PoseSequence
        do {
            sequence = try await extractor.extractPoseSequence(from: tempURL)
        } catch {
            #if DEBUG && targetEnvironment(simulator)
            guard DebugFormAnalysisVideoProvider.launchVideoURL != nil else { throw error }
            sequence = .exerciseFixture(exercise, quality: .risky)
            #else
            throw error
            #endif
        }
        let summary = ruleEngine.analyze(exercise: exercise, sequence: sequence)
        let feedbackPlan = feedbackPlanner.makePlan(
            exercise: exercise,
            sequence: sequence,
            issues: summary.issues
        )
        let feedbackImage = try await overlayRenderer.render(videoURL: tempURL, plan: feedbackPlan)

        return LocalFormAnalysisArtifact(
            summary: summary,
            feedbackImageData: feedbackImage,
            duration: sequence.duration,
            feedbackTimestamp: feedbackPlan.frame.timestamp
        )
    }
}
