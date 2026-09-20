import Foundation
import SwiftData

@MainActor
struct HealthContextBuilder {
    let modelContext: ModelContext
    private let calendar = Calendar.current
    private let language = AppLanguagePolicy.current

    func aiContextIfEnabled(maxDays: Int = 30) -> String? {
        guard preference()?.aiHealthContextEnabled == true else { return nil }
        let context = buildContext(maxDays: maxDays)
        return context.isEmpty ? nil : context
    }

    func buildContext(maxDays: Int = 30) -> String {
        let summaries = recentSummaries(maxDays: maxDays)
        let dailyReport = latestDailyReport()
        let weeklyReport = latestWeeklyReport()
        let mealStats = recentMealStats(days: min(maxDays, 30))
        let trainingStats = recentTrainingStats(days: min(maxDays, 30))
        let formStats = recentFormStats()

        guard !summaries.isEmpty || dailyReport != nil || weeklyReport != nil || mealStats.hasData || trainingStats.completedExercises > 0 else {
            return ""
        }

        let dailyLines = summaries.suffix(14).map { summary in
            "- \(dateString(summary.date)): sleep=\(minutes(summary.sleepMinutes)), hrv=\(number(summary.hrvSDNN, unit: "ms")), restingHR=\(number(summary.restingHeartRate, unit: "bpm")), steps=\(Int(summary.steps.rounded())), activeEnergy=\(Int(summary.activeEnergyKcal.rounded()))kcal, workout=\(minutes(summary.workoutMinutes))"
        }.joined(separator: "\n")

        let intro = language.prefersSimplifiedChinese
            ? "以下是用户授权的 FitGenius 健康与训练恢复上下文。只能用于训练恢复、饮食执行和训练调整建议；不要做医疗诊断。若出现持续异常或明显健康风险，请建议咨询医生。"
            : "Below is the user's authorized FitGenius health and training-recovery context. Use it only for training recovery, nutrition adherence, and programming suggestions. Do not make medical diagnoses; recommend professional care for persistent abnormal signals or clear health concerns."

        return """
        \(intro)

        daily_readiness:
        \(dailyReportSummary(dailyReport))

        weekly_report:
        \(weeklyReportSummary(weeklyReport))

        recent_daily_health_series:
        \(dailyLines.isEmpty ? "no HealthKit daily series available" : dailyLines)

        training_last_\(min(maxDays, 30))d:
        completedExercises=\(trainingStats.completedExercises), trainingDays=\(trainingStats.trainingDays), estimatedVolume=\(Int(trainingStats.volume.rounded()))

        nutrition_last_\(min(maxDays, 30))d:
        averageCalories=\(Int(mealStats.calories.rounded())), protein=\(Int(mealStats.protein.rounded()))g, carbs=\(Int(mealStats.carbs.rounded()))g, fat=\(Int(mealStats.fat.rounded()))g

        form_analysis:
        \(formStats)
        """
    }

    private func preference() -> HealthInsightPreference? {
        try? modelContext.fetch(FetchDescriptor<HealthInsightPreference>()).first
    }

    private func recentSummaries(maxDays: Int) -> [HealthDailySummary] {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -maxDays + 1, to: Date()) ?? Date())
        let descriptor = FetchDescriptor<HealthDailySummary>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func latestDailyReport() -> DailyReadinessReportRecord? {
        let descriptor = FetchDescriptor<DailyReadinessReportRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func latestWeeklyReport() -> WeeklyHealthReportRecord? {
        let descriptor = FetchDescriptor<WeeklyHealthReportRecord>(
            sortBy: [SortDescriptor(\.weekStart, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func recentTrainingStats(days: Int) -> (completedExercises: Int, trainingDays: Int, volume: Double) {
        let start = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate { $0.date >= start }
        )
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        let volume = logs.reduce(0) { partial, log in
            partial + Double(log.actualSets) * parseReps(log.actualReps) * max(log.actualWeight, 1)
        }
        let trainingDays = Set(logs.map { calendar.startOfDay(for: $0.date) }).count
        return (logs.count, trainingDays, volume)
    }

    private func recentMealStats(days: Int) -> (hasData: Bool, calories: Double, protein: Double, carbs: Double, fat: Double) {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days + 1, to: Date()) ?? Date())
        let descriptor = FetchDescriptor<MealDay>(
            predicate: #Predicate { $0.date >= start }
        )
        let mealDays = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.summary != nil }
        guard !mealDays.isEmpty else { return (false, 0, 0, 0, 0) }
        let totals = mealDays.reduce((calories: 0.0, protein: 0.0, carbs: 0.0, fat: 0.0)) { partial, day in
            guard let summary = day.summary else { return partial }
            return (
                partial.calories + summary.totalCalories,
                partial.protein + summary.protein,
                partial.carbs + summary.carbs,
                partial.fat + summary.fat
            )
        }
        let count = Double(mealDays.count)
        return (true, totals.calories / count, totals.protein / count, totals.carbs / count, totals.fat / count)
    }

    private func recentFormStats() -> String {
        let descriptor = FetchDescriptor<FormAnalysisRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let records = ((try? modelContext.fetch(descriptor)) ?? []).prefix(3)
        guard !records.isEmpty else { return "no recent form analysis" }
        return records.map { record in
            let issue = record.issues.first?.title ?? "stable"
            return "- \(record.exerciseType.displayName): score=\(record.score), issue=\(issue)"
        }.joined(separator: "\n")
    }

    private func dailyReportSummary(_ report: DailyReadinessReportRecord?) -> String {
        guard let report else { return "not generated" }
        let reasons = report.reasons.map { "\($0.title): \($0.detail)" }.joined(separator: " | ")
        let sleepRecovery = report.sleepRecoveryPercent >= 0
            ? "\(report.sleepRecoveryPercent)%"
            : "unavailable"
        return "score=\(report.energyScore), status=\(report.status.localizedName), recommendation=\(report.recommendation.localizedName), sleepRecovery=\(sleepRecovery), reasons=\(reasons)"
    }

    private func weeklyReportSummary(_ report: WeeklyHealthReportRecord?) -> String {
        guard let report else { return "not generated" }
        return "score=\(report.energyScore), trainingExecution=\(report.trainingExecutionPercent)%, summary=\(report.summary), nextWeekAdvice=\(report.nextWeekAdvice)"
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func minutes(_ value: Double) -> String {
        guard value > 0 else { return "n/a" }
        return "\(Int(value.rounded()))m"
    }

    private func number(_ value: Double, unit: String) -> String {
        guard value > 0 else { return "n/a" }
        return "\(Int(value.rounded()))\(unit)"
    }

    private func parseReps(_ reps: String) -> Double {
        if reps.contains("-") {
            let parts = reps.split(separator: "-")
            if parts.count == 2,
               let min = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let max = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                return (min + max) / 2
            }
        }
        return Double(reps) ?? 10
    }
}
