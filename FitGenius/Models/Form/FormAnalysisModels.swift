import Foundation
import SwiftData

enum FormAnalysisSyncStatus: String, Codable {
    case pending
    case synced
    case failed
}

@Model
final class FormAnalysisRecord {
    var date: Date
    var exerciseName: String
    var exerciseTypeRaw: String
    var score: Int
    var issuesJSON: String
    var metricsJSON: String
    var recommendation: String
    var videoDuration: Double
    var syncStatusRaw: String
    var lastSyncAttemptAt: Date?
    var lastSyncedAt: Date?
    var syncErrorMessage: String

    init(
        date: Date = Date(),
        exerciseName: String,
        exerciseType: FormExerciseType,
        score: Int,
        issuesJSON: String,
        metricsJSON: String,
        recommendation: String,
        videoDuration: Double,
        syncStatus: FormAnalysisSyncStatus = .pending,
        lastSyncAttemptAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        syncErrorMessage: String = ""
    ) {
        self.date = date
        self.exerciseName = exerciseName
        self.exerciseTypeRaw = exerciseType.rawValue
        self.score = score
        self.issuesJSON = issuesJSON
        self.metricsJSON = metricsJSON
        self.recommendation = recommendation
        self.videoDuration = videoDuration
        self.syncStatusRaw = syncStatus.rawValue
        self.lastSyncAttemptAt = lastSyncAttemptAt
        self.lastSyncedAt = lastSyncedAt
        self.syncErrorMessage = syncErrorMessage
    }

    var exerciseType: FormExerciseType {
        FormExerciseType(rawValue: exerciseTypeRaw) ?? .squat
    }

    var issues: [FormIssue] {
        decode([FormIssue].self, from: issuesJSON) ?? []
    }

    var metrics: [FormMetric] {
        decode([FormMetric].self, from: metricsJSON) ?? []
    }

    var syncStatus: FormAnalysisSyncStatus {
        get { FormAnalysisSyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    func markSyncSucceeded(at date: Date = Date()) {
        syncStatus = .synced
        lastSyncAttemptAt = date
        lastSyncedAt = date
        syncErrorMessage = ""
    }

    func markSyncFailed(_ message: String, at date: Date = Date()) {
        syncStatus = .failed
        lastSyncAttemptAt = date
        syncErrorMessage = message
    }
}

func encodeJSONString<T: Encodable>(_ value: T) -> String {
    guard let data = try? JSONEncoder().encode(value) else { return "[]" }
    return String(data: data, encoding: .utf8) ?? "[]"
}

func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
    guard let data = string.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
}
