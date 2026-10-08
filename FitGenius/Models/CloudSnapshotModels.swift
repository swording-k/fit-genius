import Foundation
import SwiftData

struct CloudSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let profile: CloudProfile?
    let workoutPlan: CloudWorkoutPlan?
    let mealDays: [CloudMealDay]
    let healthDailySummaries: [CloudHealthDailySummary]?
    let dailyReadinessReports: [CloudDailyReadinessReport]?
    let weeklyHealthReports: [CloudWeeklyHealthReport]?

    var hasMeaningfulData: Bool {
        profile != nil
        || !(workoutPlan?.days ?? []).isEmpty
        || mealDays.contains { !$0.entries.isEmpty || $0.submitted }
        || !(healthDailySummaries ?? []).isEmpty
        || !(dailyReadinessReports ?? []).isEmpty
        || !(weeklyHealthReports ?? []).isEmpty
    }

    @MainActor
    static func make(from context: ModelContext) throws -> CloudSnapshot {
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        let plan = CurrentWorkoutPlanStore.resolve(profiles: profiles, plans: plans)
        let profile = profiles.first { $0.workoutPlan === plan } ?? profiles.first
        let mealDays = try context.fetch(FetchDescriptor<MealDay>())
        let healthSummaries = try context.fetch(FetchDescriptor<HealthDailySummary>())
        let dailyReports = try context.fetch(FetchDescriptor<DailyReadinessReportRecord>())
        let weeklyReports = try context.fetch(FetchDescriptor<WeeklyHealthReportRecord>())
        return CloudSnapshot(
            schemaVersion: 2,
            profile: profile.map(CloudProfile.init),
            workoutPlan: plan.map(CloudWorkoutPlan.init),
            mealDays: mealDays.sorted { $0.date < $1.date }.map(CloudMealDay.init),
            healthDailySummaries: Array(healthSummaries.sorted { $0.date < $1.date }.suffix(30)).map(CloudHealthDailySummary.init),
            dailyReadinessReports: Array(dailyReports.sorted { $0.date < $1.date }.suffix(14)).map(CloudDailyReadinessReport.init),
            weeklyHealthReports: Array(weeklyReports.sorted { $0.weekStart < $1.weekStart }.suffix(8)).map(CloudWeeklyHealthReport.init)
        )
    }

    @MainActor
    func replaceLocalData(in context: ModelContext, userId: String?) throws {
        for profile in try context.fetch(FetchDescriptor<UserProfile>()) {
            context.delete(profile)
        }
        for plan in try context.fetch(FetchDescriptor<WorkoutPlan>()) {
            context.delete(plan)
        }
        for day in try context.fetch(FetchDescriptor<MealDay>()) {
            context.delete(day)
        }
        for summary in try context.fetch(FetchDescriptor<HealthDailySummary>()) {
            context.delete(summary)
        }
        for report in try context.fetch(FetchDescriptor<DailyReadinessReportRecord>()) {
            context.delete(report)
        }
        for report in try context.fetch(FetchDescriptor<WeeklyHealthReportRecord>()) {
            context.delete(report)
        }

        var restoredProfile: UserProfile?
        if let profile {
            let item = profile.makeModel()
            item.userId = userId
            context.insert(item)
            restoredProfile = item
        }
        if let workoutPlan {
            let plan = workoutPlan.makeModel()
            plan.userId = userId
            plan.userProfile = restoredProfile
            restoredProfile?.workoutPlan = plan
            context.insert(plan)
        }
        for day in mealDays {
            context.insert(day.makeModel())
        }
        for summary in healthDailySummaries ?? [] {
            context.insert(summary.makeModel())
        }
        for report in dailyReadinessReports ?? [] {
            context.insert(report.makeModel())
        }
        for report in weeklyHealthReports ?? [] {
            context.insert(report.makeModel())
        }
        try context.save()
    }
}

struct CloudProfile: Codable, Equatable {
    let name: String
    let nickname: String?
    let age: Int
    let height: Double
    let weight: Double
    let goal: FitnessGoal
    let goals: [FitnessGoal]?   // v1.5 多选目标（可选，兼容旧单值 goal）
    let environment: WorkoutEnvironment
    let availableEquipment: [String]
    let injuries: String
    let streakDays: Int
    let lastCompletedDate: Date?
    let lastCheckDate: Date?

    @MainActor init(_ model: UserProfile) {
        name = model.name
        nickname = model.nickname
        age = model.age
        height = model.height
        weight = model.weight
        goal = model.goal
        goals = model.goals
        environment = model.environment
        availableEquipment = model.availableEquipment
        injuries = model.injuries
        streakDays = model.streakDays
        lastCompletedDate = model.lastCompletedDate
        lastCheckDate = model.lastCheckDate
    }

    @MainActor func makeModel() -> UserProfile {
        let model = UserProfile(
            name: name,
            age: age,
            height: height,
            weight: weight,
            goal: goal,
            environment: environment,
            availableEquipment: availableEquipment,
            injuries: injuries
        )
        model.nickname = nickname
        model.streakDays = streakDays
        model.lastCompletedDate = lastCompletedDate
        model.lastCheckDate = lastCheckDate
        model.goals = goals
        return model
    }
}

struct CloudWorkoutPlan: Codable, Equatable {
    let creationDate: Date
    let name: String
    let days: [CloudWorkoutDay]

    @MainActor init(_ model: WorkoutPlan) {
        creationDate = model.creationDate
        name = model.name
        days = (model.days ?? []).sorted { $0.dayNumber < $1.dayNumber }.map(CloudWorkoutDay.init)
    }

    @MainActor func makeModel() -> WorkoutPlan {
        let plan = WorkoutPlan(name: name, creationDate: creationDate)
        plan.days = days.map { day in
            let model = day.makeModel()
            model.plan = plan
            return model
        }
        return plan
    }
}

struct CloudWorkoutDay: Codable, Equatable {
    let dayNumber: Int
    let focus: BodyPartFocus
    let isRestDay: Bool
    let exercises: [CloudExercise]

    @MainActor init(_ model: WorkoutDay) {
        dayNumber = model.dayNumber
        focus = model.focus
        isRestDay = model.isRestDay
        exercises = (model.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }.map(CloudExercise.init)
    }

    @MainActor func makeModel() -> WorkoutDay {
        let day = WorkoutDay(dayNumber: dayNumber, focus: focus, isRestDay: isRestDay)
        day.exercises = exercises.map { exercise in
            let model = exercise.makeModel()
            model.workoutDay = day
            return model
        }
        return day
    }
}

struct CloudExercise: Codable, Equatable {
    let name: String
    let sets: Int
    let reps: String
    let weight: Double
    let notes: String
    let isCompleted: Bool
    let lastCompletedDate: Date?
    let orderIndex: Int
    let logs: [CloudExerciseLog]

    @MainActor init(_ model: Exercise) {
        name = model.name
        sets = model.sets
        reps = model.reps
        weight = model.weight
        notes = model.notes
        isCompleted = model.isCompleted
        lastCompletedDate = model.lastCompletedDate
        orderIndex = model.orderIndex
        logs = (model.logs ?? []).sorted { $0.date < $1.date }.map(CloudExerciseLog.init)
    }

    @MainActor func makeModel() -> Exercise {
        let exercise = Exercise(
            name: name,
            sets: sets,
            reps: reps,
            weight: weight,
            notes: notes,
            isCompleted: isCompleted
        )
        exercise.lastCompletedDate = lastCompletedDate
        exercise.orderIndex = orderIndex
        exercise.logs = logs.map { log in
            let model = log.makeModel()
            model.exercise = exercise
            return model
        }
        return exercise
    }
}

struct CloudExerciseLog: Codable, Equatable {
    let date: Date
    let actualWeight: Double
    let actualSets: Int
    let actualReps: String

    @MainActor init(_ model: ExerciseLog) {
        date = model.date
        actualWeight = model.actualWeight
        actualSets = model.actualSets
        actualReps = model.actualReps
    }

    @MainActor func makeModel() -> ExerciseLog {
        ExerciseLog(date: date, actualWeight: actualWeight, actualSets: actualSets, actualReps: actualReps)
    }
}

struct CloudMealDay: Codable, Equatable {
    let date: Date
    let submitted: Bool
    let entries: [CloudMealEntry]
    let summary: CloudNutritionSummary?

    @MainActor init(_ model: MealDay) {
        date = model.date
        submitted = model.submitted
        entries = (model.entries ?? []).sorted { $0.date < $1.date }.map(CloudMealEntry.init)
        summary = model.summary.map(CloudNutritionSummary.init)
    }

    @MainActor func makeModel() -> MealDay {
        let day = MealDay(date: date, submitted: submitted)
        day.entries = entries.map { entry in
            let model = entry.makeModel()
            model.day = day
            return model
        }
        if let summary {
            let model = summary.makeModel()
            model.day = day
            day.summary = model
        }
        return day
    }
}

struct CloudMealEntry: Codable, Equatable {
    let date: Date
    let mealType: MealType
    let text: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let source: String

    @MainActor init(_ model: MealEntry) {
        date = model.date
        mealType = model.mealType
        text = model.text
        calories = model.calories
        protein = model.protein
        carbs = model.carbs
        fat = model.fat
        source = model.source
    }

    @MainActor func makeModel() -> MealEntry {
        MealEntry(
            date: date,
            mealType: mealType,
            text: text,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            source: source
        )
    }
}

struct CloudNutritionSummary: Codable, Equatable {
    let date: Date
    let totalCalories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let notes: String

    @MainActor init(_ model: NutritionSummary) {
        date = model.date
        totalCalories = model.totalCalories
        protein = model.protein
        carbs = model.carbs
        fat = model.fat
        notes = model.notes
    }

    @MainActor func makeModel() -> NutritionSummary {
        NutritionSummary(
            date: date,
            totalCalories: totalCalories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            notes: notes
        )
    }
}

struct CloudHealthDailySummary: Codable, Equatable {
    let dto: HealthDailySummaryDTO

    @MainActor init(_ model: HealthDailySummary) {
        dto = model.dto
    }

    @MainActor func makeModel() -> HealthDailySummary {
        HealthDailySummary(dto: dto)
    }
}

struct CloudDailyReadinessReport: Codable, Equatable {
    let date: Date
    let energyScore: Int
    let sleepRecoveryPercent: Int
    let dataCoveragePercent: Int?
    let statusRaw: String
    let recommendationRaw: String
    let summary: String
    let reasonsJSON: String
    let generatedAt: Date

    @MainActor init(_ model: DailyReadinessReportRecord) {
        date = model.date
        energyScore = model.energyScore
        sleepRecoveryPercent = model.sleepRecoveryPercent
        dataCoveragePercent = model.dataCoveragePercent
        statusRaw = model.statusRaw
        recommendationRaw = model.recommendationRaw
        summary = model.summary
        reasonsJSON = model.reasonsJSON
        generatedAt = model.generatedAt
    }

    @MainActor func makeModel() -> DailyReadinessReportRecord {
        let report = DailyReadinessReportRecord(
            date: date,
            energyScore: energyScore,
            sleepRecoveryPercent: sleepRecoveryPercent,
            dataCoveragePercent: dataCoveragePercent ?? 0,
            status: HealthRecoveryStatus(rawValue: statusRaw) ?? .insufficientData,
            recommendation: HealthTrainingRecommendation(rawValue: recommendationRaw) ?? .insufficientData,
            summary: summary,
            reasons: [],
            generatedAt: generatedAt
        )
        report.reasonsJSON = reasonsJSON
        return report
    }
}

struct CloudWeeklyHealthReport: Codable, Equatable {
    let weekStart: Date
    let weekEnd: Date
    let energyScore: Int
    let trainingExecutionPercent: Int
    let summary: String
    let nextWeekAdvice: String
    let reasonsJSON: String
    let generatedAt: Date

    @MainActor init(_ model: WeeklyHealthReportRecord) {
        weekStart = model.weekStart
        weekEnd = model.weekEnd
        energyScore = model.energyScore
        trainingExecutionPercent = model.trainingExecutionPercent
        summary = model.summary
        nextWeekAdvice = model.nextWeekAdvice
        reasonsJSON = model.reasonsJSON
        generatedAt = model.generatedAt
    }

    @MainActor func makeModel() -> WeeklyHealthReportRecord {
        let report = WeeklyHealthReportRecord(
            weekStart: weekStart,
            weekEnd: weekEnd,
            energyScore: energyScore,
            trainingExecutionPercent: trainingExecutionPercent,
            summary: summary,
            nextWeekAdvice: nextWeekAdvice,
            reasons: [],
            generatedAt: generatedAt
        )
        report.reasonsJSON = reasonsJSON
        return report
    }
}
