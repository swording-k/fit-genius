import Foundation

@main
enum FormAnalysisSyncPayloadTests {
    static func main() throws {
        assertEqual(FormExerciseType.squat.syncIdentifier, "squat", "squat sync identifier")
        assertEqual(FormExerciseType.deadlift.syncIdentifier, "deadlift", "deadlift sync identifier")
        assertEqual(FormExerciseType.benchPress.syncIdentifier, "bench_press", "bench sync identifier")
        assertEqual(FormExerciseType.overheadPress.syncIdentifier, "overhead_press", "overhead press sync identifier")

        let issue = FormIssue(
            code: "bench_wrist_path",
            title: "Press path is unstable",
            detail: "The wrists shift during the press.",
            severity: 2
        )
        let metric = FormMetric(
            key: "bench_range_of_motion",
            label: "Range of Motion",
            value: 0.19,
            unit: "norm"
        )
        let analyzedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let payload = FormAnalysisSyncPayload(
            localIdentifier: "local-form-1",
            analyzedAt: analyzedAt,
            exerciseName: "卧推",
            exerciseType: .benchPress,
            score: 88,
            issues: [issue],
            metrics: [metric],
            recommendation: "Keep the current weight.",
            videoDuration: 15.7
        )

        assertEqual(payload.schemaVersion, 1, "schema version")
        assertEqual(payload.sourcePlatform, "ios", "source platform")
        assertEqual(payload.exerciseType, "bench_press", "payload exercise type")

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(FormAnalysisSyncPayload.self, from: data)

        assertEqual(decoded, payload, "payload should survive JSON round trip")
        assertEqual(decoded.issues.first?.code, "bench_wrist_path", "issue code should round trip")
        assertEqual(decoded.metrics.first?.key, "bench_range_of_motion", "metric key should round trip")

        let record = FormAnalysisRecord(
            date: analyzedAt,
            exerciseName: "卧推",
            exerciseType: .benchPress,
            score: 88,
            issuesJSON: encodeJSONString([issue]),
            metricsJSON: encodeJSONString([metric]),
            recommendation: "Keep the current weight.",
            videoDuration: 15.7
        )
        let recordPayload = record.syncPayload()

        assertEqual(recordPayload.localIdentifier, "form-1780000000000-bench_press-x", "record local identifier")
        assertEqual(recordPayload.exerciseType, "bench_press", "record payload exercise type")
        assertEqual(recordPayload.issues, [issue], "record issues")
        assertEqual(recordPayload.metrics, [metric], "record metrics")
        assertEqual(record.syncStatus, .pending, "new records should start pending sync")

        record.markSyncSucceeded(at: analyzedAt.addingTimeInterval(30))
        assertEqual(record.syncStatus, .synced, "successful sync status")
        assertEqual(record.lastSyncedAt, analyzedAt.addingTimeInterval(30), "successful sync date")
        assertEqual(record.syncErrorMessage, "", "successful sync clears error")

        record.markSyncFailed("network_timeout", at: analyzedAt.addingTimeInterval(60))
        assertEqual(record.syncStatus, .failed, "failed sync status")
        assertEqual(record.lastSyncAttemptAt, analyzedAt.addingTimeInterval(60), "failed sync attempt date")
        assertEqual(record.syncErrorMessage, "network_timeout", "failed sync error")

        print("FormAnalysisSyncPayloadTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            print("FormAnalysisSyncPayloadTests failed: \(message). Expected \(expected), got \(actual)")
            exit(1)
        }
    }
}
