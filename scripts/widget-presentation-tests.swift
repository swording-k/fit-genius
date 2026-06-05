import Foundation

@main
struct WidgetPresentationTests {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let workout = WidgetWorkoutData(
            dayName: "Day 1",
            focus: "Chest",
            exercises: [
                WidgetExerciseData(name: "Bench Press", sets: 4, reps: "8", weight: 80, isCompleted: true),
                WidgetExerciseData(name: "Incline Press", sets: 3, reps: "10", weight: 30, isCompleted: false),
                WidgetExerciseData(name: "Fly", sets: 3, reps: "12", weight: 12, isCompleted: false),
                WidgetExerciseData(name: "Push-up", sets: 2, reps: "AMRAP", weight: 0, isCompleted: false)
            ],
            isRestDay: false,
            cycleWeek: 1,
            cycleDay: 1
        )
        let presentation = WidgetWorkoutPresentation(workout: workout)
        expect(presentation.completedCount == 1, "completed count should ignore pending exercises")
        expect(presentation.totalCount == 4, "total count should include every exercise")
        expect(presentation.progress == 0.25, "progress should be normalized")
        expect(presentation.nextExercise?.name == "Incline Press", "next exercise should be first pending exercise")
        expect(presentation.upcomingExercises.map(\.name) == ["Incline Press", "Fly"], "medium widget should show at most two upcoming exercises")

        let diet = WidgetDietData(totalCalories: 1800, protein: 100, carbs: 200, fat: 60, hasData: true)
        let dietPresentation = WidgetDietPresentation(diet: diet)
        let totalShare = dietPresentation.proteinShare + dietPresentation.carbsShare + dietPresentation.fatShare
        expect(abs(totalShare - 1.0) < 0.0001, "macro shares should be normalized from 4/4/9 calories")
        expect(dietPresentation.carbsShare > dietPresentation.proteinShare, "carb share should reflect gram and calorie contribution")
        expect(dietPresentation.fatShare > dietPresentation.proteinShare, "fat share should use 9 kcal per gram")
        print("Widget presentation tests passed")
    }
}
