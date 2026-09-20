import SwiftData
import SwiftUI

/// Learning surface for one exercise instance in the user's current plan.
/// The plan prescription remains visible even when no library template or
/// creator tutorial has been mapped yet.
struct PlannedExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @Query(sort: \ExerciseTemplate.nameEn) private var templates: [ExerciseTemplate]

    private var resolvedTemplate: ExerciseTemplate? {
        if let template = exercise.template { return template }
        let candidates = templates.map {
            ExerciseTemplateResolver.Candidate(
                id: $0.externalId,
                names: [$0.nameEn, $0.displayName, $0.chineseName].compactMap { $0 }
            )
        }
        guard let id = ExerciseTemplateResolver.resolve(exercise.name, in: candidates) else { return nil }
        return templates.first { $0.externalId == id }
    }

    var body: some View {
        List {
            prescriptionSection

            if let template = resolvedTemplate {
                ExerciseLearningContent(template: template, formAnalysisExercise: exercise)
            } else {
                Section {
                    ContentUnavailableView(
                        "planned_exercise_unmatched_title",
                        systemImage: "questionmark.circle",
                        description: Text("planned_exercise_unmatched_message")
                    )
                }
            }

        }
        .navigationTitle(exercise.localizedDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .hidesGlobalModeToggle()
    }

    private var prescriptionSection: some View {
        Section("planned_exercise_prescription") {
            LabeledContent("sets", value: "\(exercise.sets)")
            LabeledContent("reps", value: exercise.reps)
            if exercise.weight > 0 {
                LabeledContent("weight", value: "\(exercise.weight.formatted()) \("kg".localized)")
            }
            if !exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(exercise.notes)
                    .foregroundColor(.secondary)
            }
        }
    }

}
