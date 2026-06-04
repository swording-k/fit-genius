import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @EnvironmentObject private var workout: WatchWorkoutManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                if connectivity.isPreparedFromPhone, !workout.isActive {
                    Label("watch_prepared_from_phone", systemImage: "iphone.and.arrow.forward")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
                if let context = connectivity.workoutContext {
                    if context.isRestDay {
                        restDay
                    } else if let exercise = context.exercises.first(where: { !$0.isCompleted }) {
                        currentExercise(exercise)
                        exerciseProgress(context)
                    } else {
                        completedWorkout
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var header: some View {
        HStack {
            Label(
                workout.isActive ? String(format: NSLocalizedString("watch_heart_rate_format", comment: ""), Int(workout.heartRate)) : NSLocalizedString("watch_ready", comment: ""),
                systemImage: workout.isActive ? "heart.fill" : "figure.strengthtraining.traditional"
            )
            .font(.caption.bold())
            .foregroundStyle(workout.isActive ? .red : .green)
            Spacer()
            Button {
                workout.isActive ? workout.end() : workout.start()
            } label: {
                Image(systemName: workout.isActive ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(LocalizedStringKey(workout.isActive ? "watch_end_workout" : "watch_start_workout"))
            )
        }
    }

    private func currentExercise(_ exercise: WatchExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("watch_current_exercise").font(.caption).foregroundStyle(.secondary)
            Text(exercise.name).font(.headline)
            Text("\(exercise.sets) × \(exercise.reps) · \(exercise.weight, specifier: "%.1f") kg")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(
                String(
                    format: NSLocalizedString("watch_set_progress_format", comment: ""),
                    connectivity.completedSetCount(for: exercise),
                    exercise.sets
                )
            )
            .font(.caption.bold())

            if workout.restRemaining > 0 {
                HStack {
                    Image(systemName: "timer")
                    Text(String(format: NSLocalizedString("watch_rest_format", comment: ""), workout.restRemaining))
                        .monospacedDigit()
                    Spacer()
                    Button {
                        workout.cancelRest()
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.orange)
            } else {
                HStack(spacing: 8) {
                    Button {
                        connectivity.completeSet(exercise)
                        workout.startRest(seconds: 90)
                    } label: {
                        Label("watch_complete_set", systemImage: "checkmark")
                    }
                    .tint(.green)

                    Button {
                        workout.startRest(seconds: 90)
                    } label: {
                        Image(systemName: "timer")
                    }
                    .tint(.orange)
                    .accessibilityLabel(Text("watch_start_rest"))
                }
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func exerciseProgress(_ context: WatchWorkoutContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: NSLocalizedString("watch_progress_format", comment: ""), context.completedCount, context.exercises.count))
                .font(.caption)
            ProgressView(value: Double(context.completedCount), total: Double(max(context.exercises.count, 1)))
                .tint(.green)
        }
    }

    private var restDay: some View {
        Label("watch_rest_day", systemImage: "moon.zzz.fill")
            .font(.headline)
            .foregroundStyle(.blue)
    }

    private var completedWorkout: some View {
        Label("watch_workout_complete", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(.green)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.title2)
            Text("watch_open_iphone")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.secondary)
        .padding(.vertical, 20)
    }
}
