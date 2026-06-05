import WidgetKit
import SwiftUI

struct WidgetExerciseData: Codable, Identifiable {
    var id: UUID { uuid }
    let uuid: UUID
    let name: String
    let sets: Int
    let reps: String
    let weight: Double
    let isCompleted: Bool

    init(uuid: UUID = UUID(), name: String, sets: Int, reps: String, weight: Double, isCompleted: Bool) {
        self.uuid = uuid
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
    }
}

struct WidgetWorkoutData: Codable {
    let dayName: String
    let focus: String
    let exercises: [WidgetExerciseData]
    let isRestDay: Bool
    let cycleWeek: Int
    let cycleDay: Int
}

struct WidgetDietData: Codable {
    let totalCalories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let hasData: Bool
}

struct FitGeniusEntry: TimelineEntry {
    let date: Date
    let workoutData: WidgetWorkoutData?
    let dietData: WidgetDietData?
    let widgetContent: String
}

struct FitGeniusProvider: TimelineProvider {
    let preferredContent: String

    init(preferredContent: String = "smart") {
        self.preferredContent = preferredContent
    }

    func placeholder(in context: Context) -> FitGeniusEntry {
        FitGeniusEntry(
            date: Date(),
            workoutData: WidgetWorkoutData(
                dayName: "Day 1",
                focus: "Upper Body",
                exercises: [
                    WidgetExerciseData(name: "Bench Press", sets: 4, reps: "8", weight: 60, isCompleted: true),
                    WidgetExerciseData(name: "Incline Press", sets: 3, reps: "10", weight: 20, isCompleted: false),
                    WidgetExerciseData(name: "Cable Fly", sets: 3, reps: "12", weight: 12, isCompleted: false)
                ],
                isRestDay: false,
                cycleWeek: 1,
                cycleDay: 1
            ),
            dietData: WidgetDietData(totalCalories: 1800, protein: 120, carbs: 200, fat: 60, hasData: true),
            widgetContent: preferredContent == "smart" ? "summary" : preferredContent
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FitGeniusEntry) -> Void) {
        completion(createEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FitGeniusEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [createEntry()], policy: .after(nextUpdate)))
    }

    private func createEntry() -> FitGeniusEntry {
        let defaults = UserDefaults(suiteName: "group.com.swordingk.fitgenius")
        let workout = defaults?.data(forKey: "widgetWorkout").flatMap { try? JSONDecoder().decode(WidgetWorkoutData.self, from: $0) }
        let diet = defaults?.data(forKey: "widgetDiet").flatMap { try? JSONDecoder().decode(WidgetDietData.self, from: $0) }
        let content = preferredContent == "smart"
            ? "summary"
            : preferredContent
        return FitGeniusEntry(
            date: Date(),
            workoutData: workout,
            dietData: diet,
            widgetContent: content
        )
    }
}

struct FitGeniusWidget: Widget {
    let kind = "FitGeniusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitGeniusProvider()) { entry in
            FitGeniusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(accent: .blue)
                }
                .widgetURL(URL(string: "fitgenius://today"))
        }
        .configurationDisplayName("widget_summary_display_name")
        .description("widget_summary_description")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct FitGeniusWorkoutWidget: Widget {
    let kind = "FitGeniusWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitGeniusProvider(preferredContent: "workout")) { entry in
            FitGeniusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(accent: .blue)
                }
                .widgetURL(URL(string: "fitgenius://today"))
        }
        .configurationDisplayName("widget_workout_display_name")
        .description("widget_workout_description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct FitGeniusDietWidget: Widget {
    let kind = "FitGeniusDietWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitGeniusProvider(preferredContent: "diet")) { entry in
            FitGeniusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(accent: .orange)
                }
                .widgetURL(URL(string: "fitgenius://diet"))
        }
        .configurationDisplayName("widget_diet_display_name")
        .description("widget_diet_description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct FitGeniusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FitGeniusEntry

    var body: some View {
        Group {
            if entry.widgetContent == "summary" {
                SummaryWidgetView(workout: entry.workoutData, diet: entry.dietData, family: family)
            } else if entry.widgetContent == "diet" {
                DietWidgetView(diet: entry.dietData, family: family)
            } else {
                WorkoutWidgetView(workout: entry.workoutData, family: family)
            }
        }
        .padding(16)
    }
}

private struct WidgetBackgroundView: View {
    let accent: Color

    var body: some View {
        LinearGradient(
            colors: [
                accent.opacity(0.22),
                Color.white.opacity(0.94),
                Color.gray.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct SummaryWidgetView: View {
    let workout: WidgetWorkoutData?
    let diet: WidgetDietData?
    let family: WidgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("FitGenius", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Spacer()
                if let workout {
                    Text("\(WidgetWorkoutPresentation(workout: workout).completedCount)/\(workout.exercises.count)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                }
            }

            if let workout, !workout.isRestDay {
                let presentation = WidgetWorkoutPresentation(workout: workout)
                HStack(alignment: .center, spacing: 10) {
                    ProgressRing(progress: presentation.progress, color: .blue, lineWidth: 6)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.focus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(presentation.nextExercise?.name ?? NSLocalizedString("widget_workout_complete", comment: ""))
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
            } else {
                Label("widget_rest_day", systemImage: "moon.zzz.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)
            }

            Divider().opacity(0.35)

            if let diet, diet.hasData {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Int(diet.totalCalories), format: .number)
                        .font(.title3.bold())
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                MacroRatioBar(diet: diet)
            } else {
                Text("widget_no_diet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WorkoutWidgetView: View {
    let workout: WidgetWorkoutData?
    let family: WidgetFamily

    var body: some View {
        if let workout {
            if workout.isRestDay {
                statusView(
                    icon: "moon.zzz.fill",
                    title: "widget_rest_day",
                    detail: "widget_rest_detail",
                    color: .indigo
                )
            } else {
                workoutContent(workout)
            }
        } else {
            statusView(
                icon: "calendar.badge.plus",
                title: "widget_no_plan",
                detail: "widget_open_to_create",
                color: .blue
            )
        }
    }

    private func workoutContent(_ workout: WidgetWorkoutData) -> some View {
        let presentation = WidgetWorkoutPresentation(workout: workout)
        return VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
            HStack {
                Label("widget_today_workout", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Spacer()
                Text("\(presentation.completedCount)/\(presentation.totalCount)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.secondary)
            }

            if presentation.completedCount == presentation.totalCount, presentation.totalCount > 0 {
                Spacer()
                Label("widget_workout_complete", systemImage: "checkmark.circle.fill")
                    .font(family == .systemSmall ? .headline : .title3.bold())
                    .foregroundStyle(.green)
                Spacer()
            } else if let next = presentation.nextExercise {
                if family == .systemSmall {
                    HStack(spacing: 10) {
                        ProgressRing(progress: presentation.progress, color: .blue, lineWidth: 6)
                            .frame(width: 38, height: 38)
                        Text(workout.focus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    ProgressView(value: presentation.progress)
                        .tint(.blue)
                }

                Text(workout.focus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(next.name)
                    .font(family == .systemSmall ? .headline : .title3.bold())
                    .lineLimit(2)

                Text(exerciseDetail(next))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if family != .systemSmall {
                    Spacer(minLength: 0)
                    ForEach(presentation.upcomingExercises.dropFirst()) { exercise in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 5, height: 5)
                            Text(exercise.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(exercise.sets) × \(exercise.reps)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Spacer(minLength: 0)
                }

            } else {
                Spacer()
                Text("widget_no_exercises")
                    .font(.subheadline.bold())
                Spacer()
            }
        }
    }

    private func exerciseDetail(_ exercise: WidgetExerciseData) -> String {
        let base = "\(exercise.sets) × \(exercise.reps)"
        return exercise.weight > 0 ? "\(base) · \(exercise.weight.formatted(.number.precision(.fractionLength(0...1)))) kg" : base
    }

    private func statusView(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Spacer()
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct DietWidgetView: View {
    let diet: WidgetDietData?
    let family: WidgetFamily

    var body: some View {
        if let diet, diet.hasData {
            VStack(alignment: .leading, spacing: 10) {
                Label("widget_today_diet", systemImage: "fork.knife")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Int(diet.totalCalories), format: .number)
                        .font(family == .systemSmall ? .title2.bold() : .largeTitle.bold())
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if family == .systemSmall {
                    MacroRatioBar(diet: diet)
                } else {
                    HStack {
                        nutrient("widget_protein", value: diet.protein, color: .red)
                        nutrient("widget_carbs", value: diet.carbs, color: .blue)
                        nutrient("widget_fat", value: diet.fat, color: .orange)
                    }
                    MacroRatioBar(diet: diet)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Spacer()
                Text("widget_no_diet")
                    .font(.headline)
                Text("widget_open_to_log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func nutrient(_ label: LocalizedStringKey, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(Int(value))g").font(.caption.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

private struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct MacroRatioBar: View {
    let diet: WidgetDietData

    var body: some View {
        let presentation = WidgetDietPresentation(diet: diet)
        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 3) {
                Capsule()
                    .fill(.red)
                    .frame(width: max(width * presentation.proteinShare - 2, 3))
                Capsule()
                    .fill(.blue)
                    .frame(width: max(width * presentation.carbsShare - 2, 3))
                Capsule()
                    .fill(.orange)
                    .frame(width: max(width * presentation.fatShare - 2, 3))
            }
        }
        .frame(height: 6)
    }
}
