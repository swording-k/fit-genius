import SwiftUI
import SwiftData

// MARK: - 单个动作行视图
struct ExerciseRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: Exercise
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 完成状态 Checkbox
            Button(action: {
                exercise.toggleCompletion(context: modelContext)
            }) {
                Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(exercise.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            // 动作信息
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                    .strikethrough(exercise.isCompleted)
                    .foregroundColor(exercise.isCompleted ? .secondary : .primary)
                
                HStack(spacing: 16) {
                    Label("\(exercise.sets) 组", systemImage: "repeat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(exercise.reps, systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if exercise.weight > 0 {
                        Label("\(String(format: "%.1f", exercise.weight)) kg", systemImage: "scalemass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 编辑按钮
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - 训练日详情视图
struct WorkoutDayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutDay: WorkoutDay
    @State private var editingExercise: Exercise?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(workoutDay.dayNumber) 天")
                    .font(.title2)
                    .bold()
                
                // 根据是否是休息日显示不同标题
                if workoutDay.isRestDay {
                    Text("休息日")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(workoutDay.focus.localizedName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(workoutDay.exercises.count) 个动作")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // 动作列表或休息日提示
            if workoutDay.isRestDay {
                // 休息日提示
                VStack(spacing: 12) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("今天是休息日")
                        .font(.title3)
                        .bold()
                    Text("适当休息，强化肌肉恢复")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workoutDay.exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("暂无训练动作")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(workoutDay.exercises.sorted(by: { $0.name < $1.name })) { exercise in
                            VStack(spacing: 0) {
                                ExerciseRowView(exercise: exercise) {
                                    editingExercise = exercise
                                }
                                .padding(.horizontal)
                                
                                Divider()
                                    .padding(.leading, 60)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteExercise(exercise)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditSheet(exercise: exercise)
        }
        .onAppear {
            // 检查并重置昨天的完成状态
            for exercise in workoutDay.exercises {
                exercise.resetIfNeeded()
            }
        }
    }
    
    private func deleteExercise(_ exercise: Exercise) {
        withAnimation {
            if let index = workoutDay.exercises.firstIndex(where: { $0.id == exercise.id }) {
                workoutDay.exercises.remove(at: index)
            }
            modelContext.delete(exercise)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WorkoutDay.self, Exercise.self, configurations: config)
    
    let day = WorkoutDay(dayNumber: 1, focus: .chest)
    let ex1 = Exercise(name: "杠铃卧推", sets: 4, reps: "8-12", weight: 60)
    let ex2 = Exercise(name: "哑铃飞鸟", sets: 3, reps: "12-15", weight: 20)
    day.exercises = [ex1, ex2]
    
    return WorkoutDayDetailView(workoutDay: day)
        .modelContainer(container)
}
