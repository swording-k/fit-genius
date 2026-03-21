import SwiftUI
import SwiftData

// MARK: - 单个动作行视图（侧滑编辑删除）
struct ExerciseRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: Exercise
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    // 控制侧滑状态
    @State private var isExpanded = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 背景：编辑和删除按钮
            HStack(spacing: 0) {
                Spacer()
                
                // 编辑按钮
                Button(action: {
                    // 先收起侧滑
                    withAnimation {
                        isExpanded = false
                    }
                    // 延迟执行编辑，等动画完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onEdit()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.headline)
                        Text("edit")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.blue)
                }
                .buttonStyle(.plain)

                // 删除按钮
                Button(action: {
                    // 先收起侧滑
                    withAnimation {
                        isExpanded = false
                    }
                    // 延迟执行删除，等动画完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDelete()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.headline)
                        Text("delete")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.red)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 70)
            
            // 前景：动作信息卡片
            HStack(spacing: 12) {
                // 完成状态 Checkbox
                Button(action: {
                    exercise.toggleCompletion(context: modelContext)
                    // 刷新Widget数据
                    WidgetDataManager.updateWorkoutData(modelContext: modelContext)
                    // 发送通知
                    NotificationCenter.default.post(name: .workoutCompleted, object: nil)
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
                        Label("\(exercise.sets) \(exercise.sets.localized)", systemImage: "repeat")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label(exercise.reps, systemImage: "number")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if exercise.weight > 0 {
                            Label("\(String(format: "%.1f", exercise.weight)) \(exercise.weight.localized)", systemImage: "scalemass")
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
                
                // 触发按钮
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.left" : "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .offset(x: isExpanded ? -140 : 0)  // 左移 140 点（两个按钮的宽度）
        }
        .clipped()  // 裁剪超出部分
    }
}

// MARK: - 训练日详情视图
struct WorkoutDayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutDay: WorkoutDay
    @State private var editingExercise: Exercise?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题 + 新增动作
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workoutDay.dayNumber.localized(with: workoutDay.dayNumber))
                        .font(.title2)
                        .bold()

                    // 根据是否是休息日显示不同标题
                    if workoutDay.isRestDay {
                        Text("rest_day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(workoutDay.focus.localizedName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\((workoutDay.exercises ?? []).count) \("exercises".localized)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !workoutDay.isRestDay {
                    Button(action: { showCreateSheet = true }) {
                        Label("add_exercise", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
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
                    Text("today_is_rest_day")
                        .font(.title3)
                        .bold()
                    Text("rest_description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if (workoutDay.exercises ?? []).isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("no_exercises")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach((workoutDay.exercises ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })) { exercise in
                        ExerciseRowView(
                            exercise: exercise,
                            onEdit: {
                                editingExercise = exercise
                            },
                            onDelete: {
                                deleteExercise(exercise)
                            }
                        )
                        .listRowInsets(EdgeInsets()) // Remove default list row padding
                        .listRowSeparator(.hidden) // Hide default list row separator
                    }
                    .onMove(perform: onMove)
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditSheet(exercise: exercise)
        }
        .sheet(isPresented: $showCreateSheet) {
            ExerciseCreateSheet(workoutDay: workoutDay)
        }
        .onAppear {
            // 检查并重置昨天的完成状态
            for exercise in workoutDay.exercises ?? [] {
                exercise.resetIfNeeded()
            }
            ensureOrderIndices()
        }
    }
    
    @State private var showCreateSheet = false
    private func deleteExercise(_ exercise: Exercise) {
        withAnimation {
            if let index = (workoutDay.exercises ?? []).firstIndex(where: { $0.id == exercise.id }) {
                workoutDay.exercises?.remove(at: index)
            }
            modelContext.delete(exercise)
            normalizeOrder()
        }
    }

    private func normalizeOrder() {
        let sorted = (workoutDay.exercises ?? [])
        for (idx, ex) in sorted.enumerated() {
            ex.orderIndex = idx
        }
        try? modelContext.save()
    }
    
    private func onMove(_ source: IndexSet, _ destination: Int) {
        withAnimation {
            workoutDay.exercises?.move(fromOffsets: source, toOffset: destination)
            normalizeOrder()
        }
    }

    private func ensureOrderIndices() {
        let list = workoutDay.exercises ?? []
        let unique = Set(list.map { $0.orderIndex })
        if unique.count != list.count || unique.contains(0) {
            normalizeOrder()
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
