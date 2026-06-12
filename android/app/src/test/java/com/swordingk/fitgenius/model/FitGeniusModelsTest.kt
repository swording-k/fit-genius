package com.swordingk.fitgenius.model

import org.junit.Assert.assertEquals
import org.junit.Test

class FitGeniusModelsTest {
    @Test
    fun workoutProgressCountsCompletedSetsAcrossExercises() {
        val workout = WorkoutDay(
            title = "Test",
            focus = "Strength",
            exercises = listOf(
                Exercise(id = "a", name = "A", sets = 4, reps = "8", weightKg = 40.0, completedSets = 2),
                Exercise(id = "b", name = "B", sets = 3, reps = "10", weightKg = null, completedSets = 3)
            )
        )

        assertEquals(7, workout.totalSetCount)
        assertEquals(5, workout.completedSetCount)
        assertEquals(5f / 7f, workout.progress, 0.001f)
        assertEquals(1, workout.completedExerciseCount)
    }

    @Test
    fun nutritionSummaryAddsEveryMealMacro() {
        val meals = listOf(
            MealEntry("a", "Breakfast", 300, proteinGrams = 20.0, carbsGrams = 35.0, fatGrams = 8.0),
            MealEntry("b", "Lunch", 500, proteinGrams = 35.0, carbsGrams = 55.0, fatGrams = 14.0)
        )

        val summary = meals.nutritionSummary()

        assertEquals(800, summary.calories)
        assertEquals(55.0, summary.proteinGrams, 0.001)
        assertEquals(90.0, summary.carbsGrams, 0.001)
        assertEquals(22.0, summary.fatGrams, 0.001)
    }
}
