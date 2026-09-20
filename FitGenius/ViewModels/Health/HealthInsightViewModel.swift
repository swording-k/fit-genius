import Foundation
import Combine
import SwiftData

@MainActor
final class HealthInsightViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var isHealthAvailable = true
    @Published private(set) var isAuthorized = false
    @Published private(set) var dailyReport: DailyReadinessReportRecord?
    @Published private(set) var weeklyReport: WeeklyHealthReportRecord?
    @Published private(set) var recentSummaries: [HealthDailySummaryDTO] = []
    @Published var errorMessage: String?

    private let modelContext: ModelContext
    private let service: HealthDataService
    private let engine = RecoveryInsightEngine()
    private let calendar = Calendar.current

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.service = HealthDataService.shared
        self.isHealthAvailable = self.service.isAvailable
        loadStoredReports()
    }

    init(modelContext: ModelContext, service: HealthDataService) {
        self.modelContext = modelContext
        self.service = service
        self.isHealthAvailable = service.isAvailable
        loadStoredReports()
    }

    var preference: HealthInsightPreference {
        if let existing = try? modelContext.fetch(FetchDescriptor<HealthInsightPreference>()).first {
            return existing
        }
        let created = HealthInsightPreference()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    func loadStoredReports() {
        let dailyDescriptor = FetchDescriptor<DailyReadinessReportRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        dailyReport = try? modelContext.fetch(dailyDescriptor).first

        let weeklyDescriptor = FetchDescriptor<WeeklyHealthReportRecord>(
            sortBy: [SortDescriptor(\.weekStart, order: .reverse)]
        )
        weeklyReport = try? modelContext.fetch(weeklyDescriptor).first

        let summaryDescriptor = FetchDescriptor<HealthDailySummary>(
            sortBy: [SortDescriptor(\.date)]
        )
        recentSummaries = ((try? modelContext.fetch(summaryDescriptor)) ?? [])
            .suffix(30)
            .map(\.dto)
    }

    func requestAndRefresh(profile: UserProfile?) async {
        let pref = preference
        let scope = HealthAuthorizationScope(
            includeAdvancedVitals: pref.advancedVitalsEnabled,
            includeBodyMetrics: pref.bodyMetricsEnabled
        )
        isAuthorized = await service.requestAuthorization(scope: scope)
        guard isAuthorized else {
            errorMessage = "health_permission_denied".localized
            return
        }
        await refresh(profile: profile)
    }

    func refreshIfNeeded(profile: UserProfile?) async {
        let pref = preference
        if let last = pref.lastRefreshDate,
           calendar.isDateInToday(last),
           dailyReport != nil {
            return
        }
        await refresh(profile: profile)
    }

    func refresh(profile: UserProfile?) async {
        guard service.isAvailable else {
            isHealthAvailable = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let pref = preference
            let scope = HealthAuthorizationScope(
                includeAdvancedVitals: pref.advancedVitalsEnabled,
                includeBodyMetrics: pref.bodyMetricsEnabled
            )
            let summaries = try await service.fetchDailySummaries(days: 30, scope: scope)
            upsertSummaries(summaries)

            let daily = engine.buildDailyReport(
                input: DailyReadinessInput(
                    summaries: summaries,
                    trainingVolumeLast7Days: trainingVolume(days: 7),
                    completedExercisesLast7Days: completedExercises(days: 7),
                    proteinAverage: averageProtein(days: 7),
                    proteinTarget: proteinTarget(profile: profile),
                    isTrainingDay: profile?.workoutPlan?.getTodayWorkout()?.isRestDay == false
                )
            )
            replaceDailyReport(daily)

            let week = HealthReportWeekRange.current()
            let weekly = engine.buildWeeklyReport(
                input: WeeklyHealthInput(
                    summaries: summaries.filter { $0.date >= week.start && $0.date < week.endExclusive },
                    plannedTrainingDays: plannedTrainingDays(profile: profile, in: week),
                    completedTrainingDays: completedTrainingDays(in: week),
                    completedExercises: completedExercises(in: week),
                    trainingVolume: trainingVolume(in: week),
                    averageCalories: averageNutrition(days: 7).calories,
                    averageProtein: averageNutrition(days: 7).protein,
                    averageCarbs: averageNutrition(days: 7).carbs,
                    averageFat: averageNutrition(days: 7).fat,
                    proteinTarget: proteinTarget(profile: profile)
                ),
                weekStart: week.start,
                weekEnd: calendar.date(byAdding: .day, value: -1, to: week.endExclusive) ?? week.start
            )
            replaceWeeklyReport(weekly)

            pref.lastRefreshDate = Date()
            try? modelContext.save()
            loadStoredReports()
        } catch {
            errorMessage = error.localizedDescription
            loadStoredReports()
        }
    }

    private func upsertSummaries(_ summaries: [HealthDailySummaryDTO]) {
        for dto in summaries {
            let day = calendar.startOfDay(for: dto.date)
            let descriptor = FetchDescriptor<HealthDailySummary>(
                predicate: #Predicate { $0.date == day }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
            }
            modelContext.insert(HealthDailySummary(dto: dto))
        }
    }

    private func replaceDailyReport(_ report: DailyReadinessReportRecord) {
        let day = report.date
        let descriptor = FetchDescriptor<DailyReadinessReportRecord>(
            predicate: #Predicate { $0.date == day }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
        }
        modelContext.insert(report)
    }

    private func replaceWeeklyReport(_ report: WeeklyHealthReportRecord) {
        let start = report.weekStart
        let descriptor = FetchDescriptor<WeeklyHealthReportRecord>(
            predicate: #Predicate { $0.weekStart == start }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
        }
        modelContext.insert(report)
    }

    private func trainingLogs(since start: Date, until end: Date = Date()) -> [ExerciseLog] {
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate { $0.date >= start && $0.date <= end }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func trainingLogs(since start: Date, before endExclusive: Date) -> [ExerciseLog] {
        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate { $0.date >= start && $0.date < endExclusive }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func trainingVolume(days: Int) -> Double {
        let start = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return trainingLogs(since: start).reduce(0) { partial, log in
            partial + Double(log.actualSets) * parseReps(log.actualReps) * max(log.actualWeight, 1)
        }
    }

    private func trainingVolume(in range: HealthReportWeekRange) -> Double {
        trainingLogs(since: range.start, before: range.endExclusive).reduce(0) { partial, log in
            partial + Double(log.actualSets) * parseReps(log.actualReps) * max(log.actualWeight, 1)
        }
    }

    private func completedExercises(days: Int) -> Int {
        let start = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return trainingLogs(since: start).count
    }

    private func completedExercises(in range: HealthReportWeekRange) -> Int {
        trainingLogs(since: range.start, before: range.endExclusive).count
    }

    private func completedTrainingDays(in range: HealthReportWeekRange) -> Int {
        Set(trainingLogs(since: range.start, before: range.endExclusive).map { calendar.startOfDay(for: $0.date) }).count
    }

    private func plannedTrainingDays(profile: UserProfile?, in range: HealthReportWeekRange) -> Int {
        guard let plan = profile?.workoutPlan, plan.cycleDays > 0 else { return 0 }
        let totalDays = max(0, (calendar.dateComponents([.day], from: range.start, to: range.endExclusive).day ?? 7) - 1)
        return (0...totalDays).reduce(0) { count, offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: range.start) else { return count }
            let position = WorkoutCycleCalculator.cyclePosition(
                creationDate: plan.creationDate,
                cycleDays: plan.cycleDays,
                referenceDate: date
            )
            let day = (plan.days ?? []).sorted { $0.dayNumber < $1.dayNumber }[safe: position]
            return count + ((day?.isRestDay == false) ? 1 : 0)
        }
    }

    private func averageProtein(days: Int) -> Double {
        averageNutrition(days: days).protein
    }

    private func averageNutrition(days: Int) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days + 1, to: Date()) ?? Date())
        let descriptor = FetchDescriptor<MealDay>(
            predicate: #Predicate { $0.date >= start }
        )
        let days = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.summary != nil }
        guard !days.isEmpty else { return (0, 0, 0, 0) }
        let totals = days.reduce((calories: 0.0, protein: 0.0, carbs: 0.0, fat: 0.0)) { partial, day in
            guard let summary = day.summary else { return partial }
            return (
                partial.calories + summary.totalCalories,
                partial.protein + summary.protein,
                partial.carbs + summary.carbs,
                partial.fat + summary.fat
            )
        }
        let count = Double(days.count)
        return (totals.calories / count, totals.protein / count, totals.carbs / count, totals.fat / count)
    }

    private func proteinTarget(profile: UserProfile?) -> Double {
        guard let profile else { return 120 }
        return max(80, min(220, profile.weight * 1.6))
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
