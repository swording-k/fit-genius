import Foundation

struct DailyReadinessInput {
    var summaries: [HealthDailySummaryDTO]
    var trainingVolumeLast7Days: Double
    var completedExercisesLast7Days: Int
    var proteinAverage: Double
    var proteinTarget: Double
    var isTrainingDay: Bool
}

struct WeeklyHealthInput {
    var summaries: [HealthDailySummaryDTO]
    var plannedTrainingDays: Int
    var completedTrainingDays: Int
    var completedExercises: Int
    var trainingVolume: Double
    var averageCalories: Double
    var averageProtein: Double
    var averageCarbs: Double
    var averageFat: Double
    var proteinTarget: Double
}

final class RecoveryInsightEngine {
    private let calendar = Calendar.current
    private let language = AppLanguagePolicy.current

    func buildDailyReport(input: DailyReadinessInput, date: Date = Date()) -> DailyReadinessReportRecord {
        let sorted = input.summaries.sorted { $0.date < $1.date }
        let today = sorted.last(where: { calendar.isDate($0.date, inSameDayAs: date) }) ?? sorted.last
        let baseline = Array(sorted.dropLast().suffix(14))
        let sleepScore = sleepScore(today?.sleepMinutes, baseline: baseline.map(\.sleepMinutes))
        let hrvScore = hrvAndRestingHeartScore(today: today, baseline: baseline)
        let loadScore = trainingLoadScore(volume: input.trainingVolumeLast7Days, completedExercises: input.completedExercisesLast7Days)
        let proteinScore = proteinScore(average: input.proteinAverage, target: input.proteinTarget)
        let activityScore = activityScore(steps: today?.steps, exerciseMinutes: today?.exerciseMinutes)
        let hasTrainingHistory = input.completedExercisesLast7Days > 0

        let availableWeights: [(score: Double, weight: Double)] = [
            (sleepScore, today?.sleepMinutes == nil ? 0 : 0.35),
            (hrvScore, (today?.hrvSDNN == nil && today?.restingHeartRate == nil) ? 0 : 0.25),
            (loadScore, hasTrainingHistory ? 0.20 : 0),
            (proteinScore, input.proteinAverage <= 0 ? 0 : 0.15),
            (activityScore, (today?.steps == nil && today?.exerciseMinutes == nil) ? 0 : 0.05)
        ]
        let totalWeight = max(availableWeights.reduce(0) { $0 + $1.weight }, 0.01)
        let dataCoveragePercent = Int((min(totalWeight, 1) * 100).rounded())
        let score = Int((availableWeights.reduce(0) { $0 + $1.score * $1.weight } / totalWeight).rounded())
        let clamped = min(100, max(0, score))
        let sleepRecovery = today?.sleepMinutes == nil ? -1 : Int(sleepScore.rounded())
        let status = status(for: clamped, enoughData: totalWeight >= 0.45)
        let recommendation = recommendation(for: clamped, status: status, isTrainingDay: input.isTrainingDay)
        let reasons = dailyReasons(today: today, baseline: baseline, input: input, score: clamped)
        let summary = dailySummary(status: status, recommendation: recommendation, score: clamped)

        return DailyReadinessReportRecord(
            date: date,
            energyScore: clamped,
            sleepRecoveryPercent: sleepRecovery,
            dataCoveragePercent: dataCoveragePercent,
            status: status,
            recommendation: recommendation,
            summary: summary,
            reasons: Array(reasons.prefix(5))
        )
    }

    func buildWeeklyReport(input: WeeklyHealthInput, weekStart: Date, weekEnd: Date) -> WeeklyHealthReportRecord {
        let sleepAvg = average(input.summaries.compactMap(\.sleepMinutes))
        let hrvAvg = average(input.summaries.compactMap(\.hrvSDNN))
        let restingAvg = average(input.summaries.compactMap(\.restingHeartRate))
        let trainingExecution = input.plannedTrainingDays > 0
            ? Int((Double(input.completedTrainingDays) / Double(input.plannedTrainingDays) * 100).rounded())
            : 0
        let sleepComponent = sleepScore(sleepAvg, baseline: [])
        let proteinComponent = proteinScore(average: input.averageProtein, target: input.proteinTarget)
        let executionComponent = Double(min(100, max(0, trainingExecution)))
        let recoveryComponent = hrvAvg == nil && restingAvg == nil ? sleepComponent : min(100, max(0, 72 + ((hrvAvg ?? 45) - 45) * 0.35 - ((restingAvg ?? 65) - 65) * 0.5))
        let score = Int((sleepComponent * 0.30 + recoveryComponent * 0.25 + executionComponent * 0.25 + proteinComponent * 0.20).rounded())

        let summary: String
        let advice: String
        if language.prefersSimplifiedChinese {
            summary = "本周训练完成率 \(trainingExecution)%，平均睡眠 \(formatHours(sleepAvg))，平均蛋白质 \(Int(input.averageProtein.rounded())) g。"
            advice = score >= 75
                ? "下周可以维持当前训练节奏，优先保持睡眠和蛋白质摄入。"
                : "下周建议降低 10-20% 训练量，优先补足睡眠和蛋白质，再逐步提高强度。"
        } else {
            summary = "This week: \(trainingExecution)% training execution, \(formatHours(sleepAvg)) average sleep, \(Int(input.averageProtein.rounded())) g average protein."
            advice = score >= 75
                ? "Keep the current training rhythm next week and protect sleep and protein intake."
                : "Reduce training volume by 10-20% next week, rebuild sleep and protein consistency, then increase intensity gradually."
        }

        let reasons = weeklyReasons(input: input, sleepAvg: sleepAvg, hrvAvg: hrvAvg, restingAvg: restingAvg)
        return WeeklyHealthReportRecord(
            weekStart: weekStart,
            weekEnd: weekEnd,
            energyScore: min(100, max(0, score)),
            trainingExecutionPercent: trainingExecution,
            summary: summary,
            nextWeekAdvice: advice,
            reasons: reasons
        )
    }

    private func sleepScore(_ minutes: Double?, baseline: [Double?]) -> Double {
        guard let minutes, minutes > 0 else { return 50 }
        let baselineAverage = average(baseline.compactMap { $0 }) ?? 450
        let target = max(420, min(510, baselineAverage))
        return min(100, max(20, minutes / target * 100))
    }

    private func hrvAndRestingHeartScore(today: HealthDailySummaryDTO?, baseline: [HealthDailySummaryDTO]) -> Double {
        guard let today else { return 50 }
        var score = 72.0
        if let hrv = today.hrvSDNN, hrv > 0 {
            let base = average(baseline.compactMap(\.hrvSDNN)) ?? hrv
            score += (hrv - base) * 0.45
        }
        if let resting = today.restingHeartRate, resting > 0 {
            let base = average(baseline.compactMap(\.restingHeartRate)) ?? resting
            score -= (resting - base) * 2.0
        }
        return min(100, max(25, score))
    }

    private func trainingLoadScore(volume: Double, completedExercises: Int) -> Double {
        if completedExercises == 0 { return 72 }
        if volume > 75_000 || completedExercises >= 28 { return 55 }
        if volume > 45_000 || completedExercises >= 20 { return 68 }
        return 82
    }

    private func proteinScore(average: Double, target: Double) -> Double {
        guard average > 0, target > 0 else { return 50 }
        return min(100, max(25, average / target * 100))
    }

    private func activityScore(steps: Double?, exerciseMinutes: Double?) -> Double {
        let stepScore = min(100, max(30, (steps ?? 0) / 8000 * 100))
        let minuteScore = min(100, max(30, (exerciseMinutes ?? 0) / 30 * 100))
        return max(stepScore, minuteScore)
    }

    private func status(for score: Int, enoughData: Bool) -> HealthRecoveryStatus {
        guard enoughData else { return .insufficientData }
        if score >= 78 { return .ready }
        if score >= 58 { return .normal }
        return .low
    }

    private func recommendation(for score: Int, status: HealthRecoveryStatus, isTrainingDay: Bool) -> HealthTrainingRecommendation {
        guard status != .insufficientData else { return .insufficientData }
        if score >= 78 { return .normal }
        if score >= 62 { return isTrainingDay ? .reduceIntensity : .lightCardioMobility }
        return .recoveryDay
    }

    private func dailyReasons(today: HealthDailySummaryDTO?, baseline: [HealthDailySummaryDTO], input: DailyReadinessInput, score: Int) -> [HealthInsightReason] {
        var reasons: [HealthInsightReason] = []
        if let sleep = today?.sleepMinutes, sleep > 0 {
            let base = average(baseline.compactMap(\.sleepMinutes))
            let detail = language.prefersSimplifiedChinese
                ? "昨晚睡眠 \(formatHours(sleep))，\(base.map { "近 14 天平均 \(formatHours($0))" } ?? "暂缺稳定基线")。"
                : "Last night sleep: \(formatHours(sleep)); \(base.map { "14-day average \(formatHours($0))" } ?? "stable baseline unavailable")."
            reasons.append(HealthInsightReason(title: "health_reason_sleep".localized, detail: detail))
        }
        if let hrv = today?.hrvSDNN, hrv > 0 {
            let base = average(baseline.compactMap(\.hrvSDNN))
            let detail = language.prefersSimplifiedChinese
                ? "HRV \(Int(hrv.rounded())) ms，\(base.map { "基线约 \(Int($0.rounded())) ms" } ?? "需要更多 Apple Watch 数据建立基线")。"
                : "HRV \(Int(hrv.rounded())) ms; \(base.map { "baseline about \(Int($0.rounded())) ms" } ?? "more Apple Watch data is needed for a baseline")."
            reasons.append(HealthInsightReason(title: "health_reason_hrv".localized, detail: detail))
        }
        if input.completedExercisesLast7Days > 0 {
            let detail = language.prefersSimplifiedChinese
                ? "近 7 天完成 \(input.completedExercisesLast7Days) 个动作，训练量约 \(Int(input.trainingVolumeLast7Days.rounded()))。"
                : "Last 7 days: \(input.completedExercisesLast7Days) exercises completed, estimated volume \(Int(input.trainingVolumeLast7Days.rounded()))."
            reasons.append(HealthInsightReason(title: "health_reason_training_load".localized, detail: detail))
        }
        if input.proteinAverage > 0 {
            let detail = language.prefersSimplifiedChinese
                ? "近期平均蛋白质 \(Int(input.proteinAverage.rounded())) g，目标约 \(Int(input.proteinTarget.rounded())) g。"
                : "Recent average protein \(Int(input.proteinAverage.rounded())) g, target about \(Int(input.proteinTarget.rounded())) g."
            reasons.append(HealthInsightReason(title: "health_reason_protein".localized, detail: detail))
        }
        if reasons.isEmpty {
            reasons.append(HealthInsightReason(title: "health_reason_data".localized, detail: "health_data_needed_detail".localized))
        }
        return reasons
    }

    private func weeklyReasons(input: WeeklyHealthInput, sleepAvg: Double?, hrvAvg: Double?, restingAvg: Double?) -> [HealthInsightReason] {
        var reasons: [HealthInsightReason] = [
            HealthInsightReason(
                title: "health_reason_training_execution".localized,
                detail: language.prefersSimplifiedChinese
                    ? "计划 \(input.plannedTrainingDays) 天，完成 \(input.completedTrainingDays) 天。"
                    : "\(input.completedTrainingDays) of \(input.plannedTrainingDays) planned training days completed."
            )
        ]
        if let sleepAvg {
            reasons.append(HealthInsightReason(title: "health_reason_sleep".localized, detail: language.prefersSimplifiedChinese ? "本周平均睡眠 \(formatHours(sleepAvg))。" : "Average sleep this week: \(formatHours(sleepAvg))."))
        }
        if let hrvAvg {
            reasons.append(HealthInsightReason(title: "health_reason_hrv".localized, detail: language.prefersSimplifiedChinese ? "本周平均 HRV \(Int(hrvAvg.rounded())) ms。" : "Average HRV this week: \(Int(hrvAvg.rounded())) ms."))
        }
        if input.averageProtein > 0 {
            reasons.append(HealthInsightReason(title: "health_reason_protein".localized, detail: language.prefersSimplifiedChinese ? "平均蛋白质 \(Int(input.averageProtein.rounded())) g，目标约 \(Int(input.proteinTarget.rounded())) g。" : "Average protein \(Int(input.averageProtein.rounded())) g, target about \(Int(input.proteinTarget.rounded())) g."))
        }
        return Array(reasons.prefix(5))
    }

    private func dailySummary(status: HealthRecoveryStatus, recommendation: HealthTrainingRecommendation, score: Int) -> String {
        if language.prefersSimplifiedChinese {
            return "今日身体能量 \(score) 分，状态为\(status.localizedName)。建议：\(recommendation.localizedName)。"
        }
        return "Today's energy score is \(score). Status: \(status.localizedName). Recommendation: \(recommendation.localizedName)."
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func formatHours(_ minutes: Double?) -> String {
        guard let minutes, minutes > 0 else { return "health_data_unavailable".localized }
        let hours = Int(minutes / 60)
        let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
        if language.prefersSimplifiedChinese {
            return "\(hours)h\(mins)m"
        }
        return "\(hours)h \(mins)m"
    }
}
