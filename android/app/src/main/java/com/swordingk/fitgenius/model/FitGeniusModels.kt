package com.swordingk.fitgenius.model

data class Exercise(
    val id: String,
    val name: String,
    val sets: Int,
    val reps: String,
    val weightKg: Double?,
    val completedSets: Int = 0
) {
    val progress: Float
        get() = if (sets <= 0) 0f else (completedSets.coerceIn(0, sets).toFloat() / sets.toFloat())
}

data class WorkoutDay(
    val title: String,
    val focus: String,
    val exercises: List<Exercise>
) {
    val completedExerciseCount: Int
        get() = exercises.count { it.completedSets >= it.sets }

    val totalSetCount: Int
        get() = exercises.sumOf { it.sets.coerceAtLeast(0) }

    val completedSetCount: Int
        get() = exercises.sumOf { it.completedSets.coerceIn(0, it.sets.coerceAtLeast(0)) }

    val progress: Float
        get() = if (totalSetCount == 0) 0f else completedSetCount.toFloat() / totalSetCount.toFloat()
}

data class MealEntry(
    val id: String,
    val title: String,
    val calories: Int,
    val proteinGrams: Double,
    val carbsGrams: Double,
    val fatGrams: Double
)

data class NutritionSummary(
    val calories: Int,
    val proteinGrams: Double,
    val carbsGrams: Double,
    val fatGrams: Double
)

fun List<MealEntry>.nutritionSummary(): NutritionSummary =
    NutritionSummary(
        calories = sumOf { it.calories },
        proteinGrams = sumOf { it.proteinGrams },
        carbsGrams = sumOf { it.carbsGrams },
        fatGrams = sumOf { it.fatGrams }
    )

enum class SupportedLift(val displayName: String) {
    Squat("Squat"),
    Deadlift("Deadlift"),
    BenchPress("Bench Press"),
    OverheadPress("Overhead Press")
}

data class FormCoachState(
    val supportedLifts: List<SupportedLift>,
    val isMediaPipeReady: Boolean
)
