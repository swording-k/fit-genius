package com.swordingk.fitgenius.model

data class AssistantMessage(
    val id: String,
    val text: String,
    val isUser: Boolean
)

data class FitGeniusState(
    val workout: WorkoutDay,
    val meals: List<MealEntry>,
    val assistantMessages: List<AssistantMessage>
) {
    fun completeSet(exerciseId: String): FitGeniusState =
        copy(
            workout = workout.copy(
                exercises = workout.exercises.map { exercise ->
                    if (exercise.id != exerciseId) {
                        exercise
                    } else {
                        exercise.copy(
                            completedSets = (exercise.completedSets + 1).coerceAtMost(exercise.sets)
                        )
                    }
                }
            )
        )

    fun addMeal(meal: MealEntry): FitGeniusState =
        copy(meals = meals + meal)

    fun deleteMeal(mealId: String): FitGeniusState =
        copy(meals = meals.filterNot { it.id == mealId })

    fun sendAssistantMessage(
        text: String,
        coachReply: String = "I will connect to the FitGenius backend AI proxy in the next milestone. For now, your question is saved in this local Android session."
    ): FitGeniusState {
        val cleanText = text.trim()
        if (cleanText.isEmpty()) return this

        val index = assistantMessages.size + 1
        val userMessage = AssistantMessage(
            id = "user-$index",
            text = cleanText,
            isUser = true
        )
        val coachMessage = AssistantMessage(
            id = "coach-$index",
            text = coachReply,
            isUser = false
        )

        return copy(assistantMessages = assistantMessages + userMessage + coachMessage)
    }
}
