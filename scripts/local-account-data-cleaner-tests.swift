import Foundation
import SwiftData

@main
struct LocalAccountDataCleanerTests {
    static func expect(_ value: Bool) { precondition(value) }
    @MainActor static func main() async throws {
        let schema = Schema([UserProfile.self, WorkoutPlan.self, WorkoutDay.self, Exercise.self,
            ExerciseLog.self, MealDay.self, MealEntry.self, NutritionSummary.self, ChatMessage.self,
            FormAnalysisRecord.self, HealthDailySummary.self, DailyReadinessReportRecord.self,
            WeeklyHealthReportRecord.self, HealthInsightPreference.self, ExerciseTemplate.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let template = ExerciseTemplate(externalId: "test", nameEn: "Test", bodyPart: "", focusRaw: "", equipment: "", equipmentCategory: "", target: "", secondaryMuscles: [], instructionsZh: "", instructionsEn: "", mediaId: nil, gifUrl: nil, attribution: nil, suitableGym: true, suitableHome: true, suitableOutdoor: true)
        context.insert(template)
        let profile = UserProfile(name: "Test", age: 30, height: 170, weight: 70, goal: .buildMuscle, environment: .gym)
        let plan = WorkoutPlan()
        plan.userProfile = profile
        let day = WorkoutDay(dayNumber: 1, focus: .chest)
        day.plan = plan
        let exercise = Exercise(name: "Test", sets: 3, reps: "10")
        exercise.workoutDay = day
        exercise.template = template
        let log = ExerciseLog(actualWeight: 10, actualSets: 3, actualReps: "10")
        log.exercise = exercise
        let meal = MealDay()
        let entry = MealEntry(mealType: .lunch)
        entry.day = meal
        let nutrition = NutritionSummary(date: Date(), totalCalories: 100, protein: 10, carbs: 10, fat: 2)
        nutrition.day = meal
        context.insert(profile); context.insert(plan); context.insert(day); context.insert(exercise); context.insert(log)
        context.insert(meal); context.insert(entry); context.insert(nutrition)
        context.insert(ChatMessage(content: "Hello", isUser: true))
        context.insert(FormAnalysisRecord(exerciseName: "Squat", exerciseType: .squat, score: 80, issuesJSON: "[]", metricsJSON: "[]", recommendation: "", videoDuration: 10))
        context.insert(HealthDailySummary(dto: HealthDailySummaryDTO(date: Date())))
        context.insert(DailyReadinessReportRecord(date: Date(), energyScore: 70, sleepRecoveryPercent: 70, status: .normal, recommendation: .normal, summary: "", reasons: []))
        context.insert(WeeklyHealthReportRecord(weekStart: Date(), weekEnd: Date(), energyScore: 70, trainingExecutionPercent: 80, summary: "", nextWeekAdvice: "", reasons: []))
        context.insert(HealthInsightPreference())
        try context.save()
        var remoteCalls = 0
        do {
            try await LocalAccountDataCleaner.deleteAccount(context: context, hasConfiguredBackend: true, hasAppleIdentity: true, bearerToken: nil) { _ in remoteCalls += 1 }
            fatalError("missing session must fail")
        } catch {}
        assert(remoteCalls == 0)
        expect(try context.fetchCount(FetchDescriptor<HealthDailySummary>()) == 1)
        do {
            try await LocalAccountDataCleaner.deleteAccount(context: context, hasConfiguredBackend: true, hasAppleIdentity: true, bearerToken: "token") { _ in throw URLError(.notConnectedToInternet) }
            fatalError("remote failure must fail")
        } catch {}
        expect(try context.fetchCount(FetchDescriptor<WorkoutPlan>()) == 1)
        expect(try context.fetchCount(FetchDescriptor<HealthInsightPreference>()) == 1)
        try await LocalAccountDataCleaner.deleteAccount(context: context, hasConfiguredBackend: true, hasAppleIdentity: true, bearerToken: "token") { token in
            assert(token == "token"); remoteCalls += 1
            expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
        }
        for type in schema.entities.map(\.name) { print("Checked schema: \(type)") }
        func empty<T: PersistentModel>(_ model: T.Type) throws { expect(try context.fetchCount(FetchDescriptor<T>()) == 0) }
        try empty(UserProfile.self); try empty(WorkoutPlan.self); try empty(WorkoutDay.self); try empty(Exercise.self); try empty(ExerciseLog.self)
        try empty(MealDay.self); try empty(MealEntry.self); try empty(NutritionSummary.self); try empty(ChatMessage.self); try empty(FormAnalysisRecord.self)
        try empty(HealthDailySummary.self); try empty(DailyReadinessReportRecord.self); try empty(WeeklyHealthReportRecord.self); try empty(HealthInsightPreference.self)
        expect(try context.fetchCount(FetchDescriptor<ExerciseTemplate>()) == 1)
        assert(remoteCalls == 1)
        print("Local account cleaner tests passed: 14 models removed, reference library preserved, missing session/remote failure retain data")
    }
}
