package com.swordingk.fitgenius.model

object SampleData {
    val todayWorkout = WorkoutDay(
        title = "Today's Strength Plan",
        focus = "Upper Body Strength",
        exercises = listOf(
            Exercise(id = "bench", name = "Bench Press", sets = 4, reps = "6-8", weightKg = 60.0, completedSets = 1),
            Exercise(id = "row", name = "Cable Row", sets = 4, reps = "8-10", weightKg = 45.0),
            Exercise(id = "press", name = "Overhead Press", sets = 3, reps = "6-8", weightKg = 35.0),
            Exercise(id = "raise", name = "Lateral Raise", sets = 3, reps = "12-15", weightKg = 8.0)
        )
    )

    val meals = listOf(
        MealEntry(
            id = "breakfast",
            title = "Breakfast",
            calories = 520,
            proteinGrams = 31.0,
            carbsGrams = 58.0,
            fatGrams = 16.0
        ),
        MealEntry(
            id = "lunch",
            title = "Lunch",
            calories = 760,
            proteinGrams = 48.0,
            carbsGrams = 82.0,
            fatGrams = 24.0
        )
    )

    val formCoach = FormCoachState(
        supportedLifts = listOf(
            SupportedLift.Squat,
            SupportedLift.Deadlift,
            SupportedLift.BenchPress,
            SupportedLift.OverheadPress
        ),
        isMediaPipeReady = false
    )
}
