import Foundation
import SwiftData

struct CloudSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let profile: CloudProfile?
    let workoutPlan: CloudWorkoutPlan?
    let mealDays: [CloudMealDay]

    var hasMeaningfulData: Bool {
        profile != nil || workoutPlan != nil || mealDays.contains { !$0.entries.isEmpty || $0.submitted }
    }

    @MainActor
    static func make(from context: ModelContext) -> CloudSnapshot {
        let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first
        let plan = profile?.workoutPlan ?? (try? context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        let mealDays = (try? context.fetch(FetchDescriptor<MealDay>())) ?? []
        return CloudSnapshot(
            schemaVersion: 1,
            profile: profile.map(CloudProfile.init),
            workoutPlan: plan.map(CloudWorkoutPlan.init),
            mealDays: mealDays.sorted { $0.date < $1.date }.map(CloudMealDay.init)
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
