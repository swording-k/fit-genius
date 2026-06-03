import Foundation

struct FormAnalysisSyncPayload: Codable, Equatable {
    let schemaVersion: Int
    let localIdentifier: String
    let analyzedAt: Date
    let exerciseName: String
    let exerciseType: String
    let score: Int
    let issues: [FormIssue]
    let metrics: [FormMetric]
    let recommendation: String
    let videoDuration: Double
    let sourcePlatform: String

    init(
        schemaVersion: Int = 1,
        localIdentifier: String,
        analyzedAt: Date,
        exerciseName: String,
        exerciseType: FormExerciseType,
        score: Int,
        issues: [FormIssue],
        metrics: [FormMetric],
        recommendation: String,
        videoDuration: Double,
        sourcePlatform: String = "ios"
    ) {
        self.schemaVersion = schemaVersion
        self.localIdentifier = localIdentifier
        self.analyzedAt = analyzedAt
        self.exerciseName = exerciseName
        self.exerciseType = exerciseType.syncIdentifier
        self.score = score
        self.issues = issues
        self.metrics = metrics
        self.recommendation = recommendation
        self.videoDuration = videoDuration
        self.sourcePlatform = sourcePlatform
    }
}

extension FormAnalysisRecord {
    func syncPayload() -> FormAnalysisSyncPayload {
        FormAnalysisSyncPayload(
            localIdentifier: syncLocalIdentifier,
            analyzedAt: date,
            exerciseName: exerciseName,
            exerciseType: exerciseType,
            score: score,
            issues: issues,
            metrics: metrics,
            recommendation: recommendation,
            videoDuration: videoDuration
        )
    }

    var syncLocalIdentifier: String {
        let milliseconds = Int((date.timeIntervalSince1970 * 1000).rounded())
        return "form-\(milliseconds)-\(exerciseType.syncIdentifier)-\(exerciseName.syncSlug)"
    }
}

private extension String {
    var syncSlug: String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let scalars = unicodeScalars.compactMap { scalar -> String? in
            allowed.contains(scalar) ? String(scalar).lowercased() : nil
        }
        let slug = scalars.joined()
        return String((slug.isEmpty ? "x" : slug).prefix(24))
    }
}
