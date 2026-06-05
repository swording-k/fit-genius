import Foundation

struct WidgetWorkoutPresentation {
    let completedCount: Int
    let totalCount: Int
    let progress: Double
    let nextExercise: WidgetExerciseData?
    let upcomingExercises: [WidgetExerciseData]

    init(workout: WidgetWorkoutData) {
        let pending = workout.exercises.filter { !$0.isCompleted }
        totalCount = workout.exercises.count
        completedCount = max(totalCount - pending.count, 0)
        progress = totalCount == 0 ? 0 : min(max(Double(completedCount) / Double(totalCount), 0), 1)
        nextExercise = pending.first
        upcomingExercises = Array(pending.prefix(2))
    }
}

struct WidgetDietPresentation {
    let totalCalories: Double
    let proteinShare: Double
    let carbsShare: Double
    let fatShare: Double

    init(diet: WidgetDietData) {
        totalCalories = diet.totalCalories
        let proteinCalories = max(diet.protein, 0) * 4
        let carbsCalories = max(diet.carbs, 0) * 4
        let fatCalories = max(diet.fat, 0) * 9
        let macroCalories = proteinCalories + carbsCalories + fatCalories
        if macroCalories > 0 {
            proteinShare = proteinCalories / macroCalories
            carbsShare = carbsCalories / macroCalories
            fatShare = fatCalories / macroCalories
        } else {
            proteinShare = 0
            carbsShare = 0
            fatShare = 0
        }
    }
}
