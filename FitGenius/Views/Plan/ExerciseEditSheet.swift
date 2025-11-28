import SwiftUI
import SwiftData

// MARK: - 动作编辑弹窗
struct ExerciseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: Exercise
    
    @State private var editedName: String
    @State private var editedSets: String
    @State private var editedReps: String
    @State private var editedWeight: String
    @State private var editedNotes: String
    
    init(exercise: Exercise) {
        self.exercise = exercise
        _editedName = State(initialValue: exercise.name)
        _editedSets = State(initialValue: String(exercise.sets))
        _editedReps = State(initialValue: exercise.reps)
        _editedWeight = State(initialValue: String(exercise.weight))
        _editedNotes = State(initialValue: exercise.notes)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("动作信息") {
                    TextField("动作名称", text: $editedName)
                    
                    HStack {
                        Text("组数")
                        Spacer()
                        TextField("组数", text: $editedSets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("次数")
                        Spacer()
                        TextField("如: 8-12", text: $editedReps)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("重量 (kg)")
                        Spacer()
                        TextField("重量", text: $editedWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section("备注") {
                    TextEditor(text: $editedNotes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("编辑动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(editedName.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        exercise.name = editedName
        exercise.sets = Int(editedSets) ?? exercise.sets
        exercise.reps = editedReps
        exercise.weight = Double(editedWeight) ?? exercise.weight
        exercise.notes = editedNotes
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Exercise.self, configurations: config)
    let exercise = Exercise(name: "卧推", sets: 4, reps: "8-12", weight: 60, notes: "注意肩胛骨收紧")
    
    return ExerciseEditSheet(exercise: exercise)
        .modelContainer(container)
}
