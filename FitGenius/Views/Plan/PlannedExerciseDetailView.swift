import SwiftData
import SwiftUI

/// Learning surface for one exercise instance in the user's current plan.
/// The plan prescription remains visible even when no library template or
/// creator tutorial has been mapped yet.
struct PlannedExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @Query(sort: \ExerciseTemplate.nameEn) private var templates: [ExerciseTemplate]
    @State private var showFormAnalysis = false

    private let tutorialCatalog = ExerciseTutorialCatalog.loadBundled()

    private var preferChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }

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
                standardDemoSection(template)
                metadataSection(template)
                instructionsSection(template)
                tutorialSection(template)
            } else {
                Section {
                    ContentUnavailableView(
                        "planned_exercise_unmatched_title",
                        systemImage: "questionmark.circle",
                        description: Text("planned_exercise_unmatched_message")
                    )
                }
            }

            if FormExerciseType.infer(from: exercise.localizedDisplayName) != nil {
                Section {
                    Button {
                        showFormAnalysis = true
                    } label: {
                        Label("planned_exercise_form_analysis", systemImage: "figure.strengthtraining.traditional")
                    }
                }
            }
        }
        .navigationTitle(exercise.localizedDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFormAnalysis) {
            FormAnalysisView(exercise: exercise)
        }
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

    private func standardDemoSection(_ template: ExerciseTemplate) -> some View {
        Section("planned_exercise_standard_demo") {
            AnimatedGIFView(
                urlString: template.gifUrl,
                cacheKey: template.mediaId ?? template.externalId
            )
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if let attribution = template.attribution, !attribution.isEmpty {
                Text("exercise_detail_attribution_format".localized(with: attribution))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func metadataSection(_ template: ExerciseTemplate) -> some View {
        Section("planned_exercise_library_match") {
            LabeledContent("exercise_detail_body_part", value: template.focus.localizedName)
            LabeledContent(
                "exercise_detail_equipment",
                value: (ExerciseEquipmentCategory(rawValue: template.equipmentCategory) ?? .other).localizedName
            )
            LabeledContent(
                "exercise_detail_target",
                value: template.localizedTarget(preferChinese: preferChinese)
            )
            if !template.secondaryMuscles.isEmpty {
                LabeledContent(
                    "exercise_detail_secondary",
                    value: template.localizedSecondaryMuscles(preferChinese: preferChinese).joined(separator: ", ")
                )
            }
        }
    }

    private func instructionsSection(_ template: ExerciseTemplate) -> some View {
        Section("exercise_detail_instructions") {
            Text(template.localizedInstructions(preferChinese: preferChinese))
        }
    }

    @ViewBuilder
    private func tutorialSection(_ template: ExerciseTemplate) -> some View {
        let clips = tutorialCatalog.clips(for: template.externalId)
        Section("planned_exercise_real_person_tutorial") {
            if clips.isEmpty {
                Text("planned_exercise_tutorial_unavailable")
                    .foregroundColor(.secondary)
            } else {
                ForEach(clips) { clip in
                    NavigationLink {
                        ExerciseTutorialView(exercise: exercise, template: template, clip: clip)
                    } label: {
                        Label("planned_exercise_watch_tutorial", systemImage: "play.rectangle.fill")
                    }
                }
            }
        }
    }
}
