import Foundation
import SwiftData

/// Cloud deletion must succeed before any local account data is removed.
/// ExerciseTemplate is reference content, not user-owned data.
@MainActor
enum LocalAccountDataCleaner {
    static func deleteAccount(
        context: ModelContext,
        hasConfiguredBackend: Bool,
        hasAppleIdentity: Bool,
        bearerToken: String?,
        deleteRemote: (String) async throws -> Void
    ) async throws {
        if hasConfiguredBackend && (hasAppleIdentity || bearerToken != nil) {
            guard let token = bearerToken, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AccountDeletionServiceError.invalidConfiguration
            }
            try await deleteRemote(token)
        }
        try clear(context: context)
    }

    static func clear(context: ModelContext) throws {
        // Flush pending edits before the deletion transaction. If persistence
        // fails, leave the account/session intact and surface the failure.
        try context.save()
        do {
            try context.transaction {
                try context.delete(model: ExerciseLog.self)
                try context.delete(model: Exercise.self)
                try context.delete(model: WorkoutDay.self)
                try context.delete(model: WorkoutPlan.self)
                try context.delete(model: UserProfile.self)
                try context.delete(model: MealEntry.self)
                try context.delete(model: NutritionSummary.self)
                try context.delete(model: MealDay.self)
                try context.delete(model: ChatMessage.self)
                try context.delete(model: FormAnalysisRecord.self)
                try context.delete(model: HealthDailySummary.self)
                try context.delete(model: DailyReadinessReportRecord.self)
                try context.delete(model: WeeklyHealthReportRecord.self)
                try context.delete(model: HealthInsightPreference.self)
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
    }
}
