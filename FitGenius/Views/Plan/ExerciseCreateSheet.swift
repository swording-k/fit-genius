import SwiftUI
import SwiftData

struct ExerciseCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutDay: WorkoutDay
    
    @State private var name: String = ""
    @State private var sets: String = "3"
    @State private var reps: String = "8-12"
    @State private var weight: String = "0"
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("动作信息") {
                    TextField("动作名称", text: $name)
                    HStack {
                        Text("组数")
                        Spacer()
                        TextField("组数", text: $sets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("次数")
                        Spacer()
                        TextField("如: 8-12", text: $reps)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("重量 (kg)")
                        Spacer()
                        TextField("重量", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("新增动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        addExercise()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func addExercise() {
        let ex = Exercise(
            name: name,
            sets: Int(sets) ?? 3,
            reps: reps,
            weight: Double(weight) ?? 0,
            notes: notes
        )
        ex.workoutDay = workoutDay
        if workoutDay.exercises == nil { workoutDay.exercises = [] }
        ex.orderIndex = (workoutDay.exercises ?? []).count
        workoutDay.exercises?.append(ex)
        modelContext.insert(ex)
        try? modelContext.save()
    }
}