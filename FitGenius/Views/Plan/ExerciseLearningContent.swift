import SwiftUI

/// Canonical learning content for one exercise-library template.
///
/// Both the exercise library and a matched planned exercise render this view,
/// so GIFs, instructions and optional creator tutorials cannot drift apart.
struct ExerciseLearningContent: View {
    let template: ExerciseTemplate
    var formAnalysisExercise: Exercise? = nil

    @State private var showFormAnalysis = false

    @ObservedObject private var tutorials = ExerciseTutorialStore.shared

    private var preferChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }

    var body: some View {
        Group {
            standardDemoSection
            metadataSection
            instructionsSection
            tutorialSection
            formAnalysisSection
        }
        .sheet(isPresented: $showFormAnalysis) {
            if let formAnalysisExercise {
                FormAnalysisView(exercise: formAnalysisExercise)
            }
        }
        .task { await tutorials.refreshIfNeeded() }
    }

    private var standardDemoSection: some View {
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

    private var metadataSection: some View {
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

    private var instructionsSection: some View {
        Section("exercise_detail_instructions") {
            Text(template.localizedInstructions(preferChinese: preferChinese))
        }
    }

    @ViewBuilder
    private var tutorialSection: some View {
        let clips = tutorials.catalog.clips(for: template.externalId)
        Section("planned_exercise_real_person_tutorial") {
            if clips.isEmpty {
                Text("planned_exercise_tutorial_unavailable")
                    .foregroundColor(.secondary)
            } else {
                ForEach(clips) { clip in
                    NavigationLink {
                        ExerciseTutorialView(template: template, clip: clip)
                    } label: {
                        if clip.rightsStatus == .externalLinkOnly {
                            Label("planned_exercise_source", systemImage: "arrow.up.right.square")
                        } else {
                            Label("planned_exercise_watch_tutorial", systemImage: "play.rectangle.fill")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var formAnalysisSection: some View {
        if let formAnalysisExercise,
           FormExerciseType.infer(from: formAnalysisExercise.localizedDisplayName) != nil {
            Section {
                Button {
                    showFormAnalysis = true
                } label: {
                    Label(
                        "planned_exercise_form_analysis",
                        systemImage: "figure.strengthtraining.traditional"
                    )
                }
            }
        }
    }
}
