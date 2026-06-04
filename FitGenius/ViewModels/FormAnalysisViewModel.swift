import Combine
import Foundation
import SwiftData

@MainActor
final class FormAnalysisViewModel: ObservableObject {
    @Published var selectedExerciseType: FormExerciseType = .squat
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var summary: FormAnalysisSummary?

    private let extractor = PoseExtractionService()
    private let ruleEngine = FormRuleEngine()

    func inferExerciseType(from exerciseName: String) {
        if let inferred = FormExerciseType.infer(from: exerciseName) {
            selectedExerciseType = inferred
        }
    }

    func analyze(
        videoData: Data,
        exercise: Exercise,
        modelContext: ModelContext,
        userId: String? = nil,
        bearerToken: String? = nil
    ) async {
        isAnalyzing = true
        errorMessage = nil
        summary = nil
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        var insertedRecord: FormAnalysisRecord?
        do {
            try videoData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let sequence = try await extractor.extractPoseSequence(from: tempURL)
            let result = ruleEngine.analyze(exercise: selectedExerciseType, sequence: sequence)
            summary = result

            let record = FormAnalysisRecord(
                exerciseName: exercise.name,
                exerciseType: selectedExerciseType,
                score: result.score,
                issuesJSON: encodeJSONString(result.issues),
                metricsJSON: encodeJSONString(result.metrics),
                recommendation: result.recommendation,
                videoDuration: sequence.duration
            )
            modelContext.insert(record)
            try? modelContext.save()
            insertedRecord = record
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false

        // Best-effort sync — never block the analyze flow on network state.
        if let record = insertedRecord {
            #if DEBUG
            let envURL = ProcessInfo.processInfo.environment["FITGENIUS_SYNC_BACKEND_URL"] ?? ""
            if !envURL.isEmpty { SyncSettings.live.setBackendBaseURL(envURL) }
            if let envToken = ProcessInfo.processInfo.environment["FITGENIUS_DEV_SYNC_TOKEN"],
               !envToken.isEmpty {
                SyncSettings.live.setDevSyncToken(envToken)
            }
            #endif
            await FormAnalysisSyncCoordinator.shared.syncOneRecord(
                record,
                context: modelContext,
                userId: userId,
                bearerToken: bearerToken
            )
        }
    }

    func applyRecommendation(to exercise: Exercise, modelContext: ModelContext) {
        guard let summary else { return }
        let prefix = NSLocalizedString("form_note_prefix", comment: "")
        let updatedNotes = "\(prefix)\(summary.recommendation)"
        exercise.notes = exercise.notes.isEmpty ? updatedNotes : "\(exercise.notes)\n\(updatedNotes)"
        if summary.score < 70, exercise.weight > 0 {
            exercise.weight = max(0, (exercise.weight * 0.9 * 10).rounded() / 10)
        }
        try? modelContext.save()
    }
}
