package com.swordingk.fitgenius.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FitGeniusStateTest {
    @Test
    fun completeSetAdvancesOnlyTheTargetExercise() {
        val state = FitGeniusState(
            workout = WorkoutDay(
                title = "Today",
                focus = "Strength",
                exercises = listOf(
                    Exercise(id = "bench", name = "Bench", sets = 2, reps = "8", weightKg = 50.0),
                    Exercise(id = "row", name = "Row", sets = 3, reps = "10", weightKg = 40.0)
                )
            ),
            meals = emptyList(),
            assistantMessages = emptyList()
        )

        val next = state.completeSet("bench")

        assertEquals(1, next.workout.exercises.first { it.id == "bench" }.completedSets)
        assertEquals(0, next.workout.exercises.first { it.id == "row" }.completedSets)
    }

    @Test
    fun completeSetDoesNotExceedProgrammedSets() {
        val state = FitGeniusState(
            workout = WorkoutDay(
                title = "Today",
                focus = "Strength",
                exercises = listOf(
                    Exercise(id = "bench", name = "Bench", sets = 1, reps = "8", weightKg = 50.0, completedSets = 1)
                )
            ),
            meals = emptyList(),
            assistantMessages = emptyList()
        )

        val next = state.completeSet("bench")

        assertEquals(1, next.workout.exercises.first().completedSets)
    }

    @Test
    fun addAndDeleteMealUpdatesNutritionList() {
        val state = FitGeniusState(
            workout = WorkoutDay("Today", "Strength", emptyList()),
            meals = listOf(MealEntry("a", "Breakfast", 300, 20.0, 30.0, 8.0)),
            assistantMessages = emptyList()
        )

        val withMeal = state.addMeal(MealEntry("b", "Lunch", 500, 35.0, 60.0, 12.0))
        val withoutBreakfast = withMeal.deleteMeal("a")

        assertEquals(2, withMeal.meals.size)
        assertEquals(1, withoutBreakfast.meals.size)
        assertEquals("b", withoutBreakfast.meals.single().id)
    }

    @Test
    fun sendAssistantMessageAddsUserAndCoachMessages() {
        val state = FitGeniusState(
            workout = WorkoutDay("Today", "Strength", emptyList()),
            meals = emptyList(),
            assistantMessages = emptyList()
        )

        val next = state.sendAssistantMessage("How should I bench?")

        assertEquals(2, next.assistantMessages.size)
        assertTrue(next.assistantMessages[0].isUser)
        assertFalse(next.assistantMessages[1].isUser)
    }
}
