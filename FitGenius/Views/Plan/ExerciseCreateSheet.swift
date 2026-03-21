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
                Section("exercise_info") {
                    TextField("exercise_name", text: $name)
                    HStack {
                        Text("sets")
                        Spacer()
                        TextField("sets", text: $sets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("reps")
                        Spacer()
                        TextField("e.g_8_12", text: $reps)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("weight_kg")
                        Spacer()
                        TextField("weight", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                Section("notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("add_exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("add") {
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