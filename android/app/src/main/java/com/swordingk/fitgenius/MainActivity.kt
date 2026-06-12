package com.swordingk.fitgenius

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.swordingk.fitgenius.model.Exercise
import com.swordingk.fitgenius.model.MealEntry
import com.swordingk.fitgenius.model.SampleData
import com.swordingk.fitgenius.model.SupportedLift
import com.swordingk.fitgenius.model.WorkoutDay
import com.swordingk.fitgenius.model.nutritionSummary

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            FitGeniusApp()
        }
    }
}

private enum class FitGeniusTab(val labelRes: Int) {
    Training(R.string.tab_training),
    Diet(R.string.tab_diet),
    Assistant(R.string.tab_assistant),
    Form(R.string.tab_form)
}

@Composable
fun FitGeniusApp() {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Color(0xFF2563EB),
            secondary = Color(0xFF10B981),
            tertiary = Color(0xFFF97316),
            surface = Color(0xFFFFFFFF),
            background = Color(0xFFF8FAFC)
        )
    ) {
        Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            var selectedTab by rememberSaveable { mutableStateOf(FitGeniusTab.Training) }

            Scaffold(
                bottomBar = {
                    NavigationBar(containerColor = Color.White) {
                        FitGeniusTab.entries.forEach { tab ->
                            NavigationBarItem(
                                selected = selectedTab == tab,
                                onClick = { selectedTab = tab },
                                icon = { Text(tab.icon()) },
                                label = { Text(stringResource(tab.labelRes)) }
                            )
                        }
                    }
                }
            ) { padding ->
                Box(modifier = Modifier.padding(padding)) {
                    when (selectedTab) {
                        FitGeniusTab.Training -> TrainingScreen(localizedWorkout())
                        FitGeniusTab.Diet -> DietScreen(localizedMeals())
                        FitGeniusTab.Assistant -> AssistantScreen()
                        FitGeniusTab.Form -> FormCoachScreen()
                    }
                }
            }
        }
    }
}

private fun FitGeniusTab.icon(): String =
    when (this) {
        FitGeniusTab.Training -> "T"
        FitGeniusTab.Diet -> "D"
        FitGeniusTab.Assistant -> "AI"
        FitGeniusTab.Form -> "F"
    }

@Composable
private fun localizedWorkout(): WorkoutDay =
    WorkoutDay(
        title = stringResource(R.string.training_title),
        focus = stringResource(R.string.training_focus),
        exercises = listOf(
            Exercise(id = "bench", name = stringResource(R.string.exercise_bench), sets = 4, reps = "6-8", weightKg = 60.0, completedSets = 1),
            Exercise(id = "row", name = stringResource(R.string.exercise_row), sets = 4, reps = "8-10", weightKg = 45.0),
            Exercise(id = "press", name = stringResource(R.string.exercise_press), sets = 3, reps = "6-8", weightKg = 35.0),
            Exercise(id = "raise", name = stringResource(R.string.exercise_raise), sets = 3, reps = "12-15", weightKg = 8.0)
        )
    )

@Composable
private fun localizedMeals(): List<MealEntry> =
    listOf(
        MealEntry(
            id = "breakfast",
            title = stringResource(R.string.meal_breakfast),
            calories = 520,
            proteinGrams = 31.0,
            carbsGrams = 58.0,
            fatGrams = 16.0
        ),
        MealEntry(
            id = "lunch",
            title = stringResource(R.string.meal_lunch),
            calories = 760,
            proteinGrams = 48.0,
            carbsGrams = 82.0,
            fatGrams = 24.0
        )
    )

@Composable
private fun TrainingScreen(workout: WorkoutDay) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            PageHeader(
                title = workout.title,
                subtitle = workout.focus
            )
            Spacer(Modifier.height(12.dp))
            MetricCard(
                title = stringResource(R.string.workout_progress),
                value = stringResource(R.string.set_progress_format, workout.completedSetCount, workout.totalSetCount),
                accent = MaterialTheme.colorScheme.primary
            )
            Spacer(Modifier.height(12.dp))
            LinearProgressIndicator(
                progress = { workout.progress },
                modifier = Modifier.fillMaxWidth(),
                color = MaterialTheme.colorScheme.primary,
                trackColor = Color(0xFFE2E8F0)
            )
        }

        items(workout.exercises) { exercise ->
            ExerciseCard(exercise)
        }
    }
}

@Composable
private fun DietScreen(meals: List<MealEntry>) {
    val summary = meals.nutritionSummary()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            PageHeader(
                title = stringResource(R.string.nutrition_title),
                subtitle = stringResource(R.string.nutrition_subtitle)
            )
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricCard(stringResource(R.string.calories), "${summary.calories}", MaterialTheme.colorScheme.tertiary, Modifier.weight(1f))
                MetricCard(stringResource(R.string.protein), stringResource(R.string.grams_format, summary.proteinGrams.toInt()), MaterialTheme.colorScheme.secondary, Modifier.weight(1f))
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricCard(stringResource(R.string.carbs), stringResource(R.string.grams_format, summary.carbsGrams.toInt()), MaterialTheme.colorScheme.primary, Modifier.weight(1f))
                MetricCard(stringResource(R.string.fat), stringResource(R.string.grams_format, summary.fatGrams.toInt()), Color(0xFF64748B), Modifier.weight(1f))
            }
        }

        items(meals) { meal ->
            MealCard(meal)
        }
    }
}

@Composable
private fun AssistantScreen() {
    var draft by rememberSaveable { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        PageHeader(
            title = stringResource(R.string.assistant_title),
            subtitle = stringResource(R.string.assistant_subtitle)
        )

        Card(colors = CardDefaults.cardColors(containerColor = Color.White)) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(stringResource(R.string.assistant_card_title), fontWeight = FontWeight.Bold)
                Text(
                    stringResource(R.string.assistant_card_body),
                    color = Color(0xFF475569)
                )
            }
        }

        Spacer(Modifier.weight(1f))

        Row(verticalAlignment = Alignment.CenterVertically) {
            TextField(
                value = draft,
                onValueChange = { draft = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text(stringResource(R.string.assistant_placeholder)) },
                singleLine = true
            )
            Spacer(Modifier.width(10.dp))
            Button(onClick = { draft = "" }) {
                Text(stringResource(R.string.send))
            }
        }
    }
}

@Composable
private fun FormCoachScreen() {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            PageHeader(
                title = stringResource(R.string.form_title),
                subtitle = stringResource(R.string.form_subtitle)
            )
        }

        items(SampleData.formCoach.supportedLifts) { lift ->
            Card(colors = CardDefaults.cardColors(containerColor = Color.White)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(lift.localizedName(), fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.scoring_rules_align), color = Color(0xFF64748B))
                    }
                    Text(stringResource(R.string.planned), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun PageHeader(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(subtitle, color = Color(0xFF475569))
    }
}

@Composable
private fun MetricCard(
    title: String,
    value: String,
    accent: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White)
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, color = Color(0xFF64748B))
            Text(value, color = accent, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleLarge)
        }
    }
}

@Composable
private fun ExerciseCard(exercise: Exercise) {
    Card(
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(exercise.name, fontWeight = FontWeight.Bold)
                Text("${exercise.completedSets}/${exercise.sets}", color = MaterialTheme.colorScheme.primary)
            }
            Text(
                stringResource(
                    R.string.exercise_plan_format,
                    exercise.sets,
                    exercise.reps,
                    exercise.weightLabel()
                ),
                color = Color(0xFF475569)
            )
            LinearProgressIndicator(
                progress = { exercise.progress },
                modifier = Modifier.fillMaxWidth(),
                color = MaterialTheme.colorScheme.primary,
                trackColor = Color(0xFFE2E8F0)
            )
        }
    }
}

@Composable
private fun Exercise.weightLabel(): String =
    weightKg?.let { stringResource(R.string.exercise_weight_format, it.toInt()) } ?: ""

@Composable
private fun MealCard(meal: MealEntry) {
    Card(
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(meal.title, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.kcal_format, meal.calories), color = MaterialTheme.colorScheme.tertiary, fontWeight = FontWeight.SemiBold)
            }
            Text(
                stringResource(
                    R.string.meal_macro_format,
                    meal.proteinGrams.toInt(),
                    meal.carbsGrams.toInt(),
                    meal.fatGrams.toInt()
                ),
                color = Color(0xFF475569)
            )
        }
    }
}

@Composable
private fun SupportedLift.localizedName(): String =
    when (this) {
        SupportedLift.Squat -> stringResource(R.string.lift_squat)
        SupportedLift.Deadlift -> stringResource(R.string.lift_deadlift)
        SupportedLift.BenchPress -> stringResource(R.string.lift_bench)
        SupportedLift.OverheadPress -> stringResource(R.string.lift_overhead_press)
    }

@Preview(showBackground = true)
@Composable
private fun FitGeniusPreview() {
    FitGeniusApp()
}
