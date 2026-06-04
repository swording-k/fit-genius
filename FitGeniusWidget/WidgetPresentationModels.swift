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
